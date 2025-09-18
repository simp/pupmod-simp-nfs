# @param servers_with_client Array of Hosts each of which will be both an
#   NFS server and NFS client.
#
# @param opts Hash of test options with the following keys:
#  * :base_hiera    - Base hieradata to be added to nfs-specific hieradata
#  * :server_custom - Additional content to be added to the combined manifest
#  * :client_custom - Additional content to be added to the combined manifest
#  * :nfsv3         - Whether this is testing NFSv3.  When true, NFSv3 will be
#                     enabled (server + client) and used in the client mount
#  * :nfs_sec       - NFS security option to use in both the server exports and
#                     the client mounts
#  * :export_insecure - insecure setting for NFS export
#  * :mount_autodetect_remote - Array of nfs::client::mount::autodetect_remote
#                     values to test
#
shared_examples 'a NFS share using static mounts with combined client/server roles' do |servers_with_client, opts|
  let(:exported_dir) { '/srv/nfs_share' }
  let(:file_basename) { 'test_file' }
  let(:file_search_string) { 'This is a test file' }

  servers_with_client.each do |host|
    opts[:mount_autodetect_remote].each do |autodetect_remote|
      context "with autodetect_remote=#{autodetect_remote} on host #{host}" do
        let(:mount_dir) { "/mnt/#{host}-#{File.basename(exported_dir)}" }
        let(:host_opts) do
          {
            is_server: true,
            is_client: true,
            nfsv3: opts[:nfsv3],
            exported_dir: exported_dir,
            exported_file: File.join(exported_dir, file_basename),
            exported_file_content: "#{file_search_string} from #{exported_dir}",
            export_sec: opts[:nfs_sec],
            export_insecure: opts[:export_insecure],
            server_custom: opts[:server_custom],
            mount_dir: mount_dir,
            mount_server_ip: internal_network_info(host)[:ip],
            mount_remote_dir: exported_dir,
            mount_nfs_version: (opts[:nfsv3] ? 3 : 4),
            mount_sec: opts[:nfs_sec],
            mount_autodetect_remote: autodetect_remote,
            client_custom: <<~EOM,
              #{opts[:client_custom]}

              Nfs::Server::Export['#{exported_dir}'] -> Nfs::Client::Mount['#{mount_dir}']
              Service['nfs-server.service'] -> Nfs::Client::Mount['#{mount_dir}']
            EOM
          }
        end

        let(:manifest) do
          [
            create_export_manifest(host_opts),
            '',
            create_static_mount_manifest(host_opts),
          ].join("\n")
        end

        it 'ensures vagrant connectivity' do
          on(hosts, 'date')
        end

        it 'applies server+client manifest to export+mount' do
          hieradata = build_host_hiera(opts[:base_hiera], host_opts)
          set_hieradata_on(host, hieradata)
          print_test_config(hieradata, manifest)
          apply_manifest_on(host, manifest, catch_failures: true)
        end

        it 'is idempotent' do
          apply_manifest_on(host, manifest, catch_changes: true)
        end

        it 'exports shared dir' do
          on(host, 'exportfs -v')
          on(host, "exportfs | grep #{exported_dir}")
        end

        it 'mounts NFS share' do
          on(host, %(grep -q '#{file_search_string}' #{mount_dir}/#{file_basename}))
        end

        it 'removes mount as prep for next test' do
          # use puppet resource instead of simple umount, in order to remove
          # persistent mount configuration
          on(host, %(puppet resource mount #{mount_dir} ensure=absent))
          on(host, "rm -rf #{mount_dir}")
        end
      end
    end
  end
end
