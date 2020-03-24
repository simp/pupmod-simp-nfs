# Verify two NFS clients can simultaneously mount the same directory from
# a NFS server
#
#   client1 mount ----> server exported dir
#                       ^
#   client2 mount ------'
#
# This test is most useful for verifying a server supports simultaneous
# stunneled and non-stunneled connections to different clients.
#
# Characteristics of the server capabilities, server exports and clients mounts
# (e.g., stunnel, NFSv4 or NFSv3, insecure export) are controlled by opts.
#
# @param servers Array of Hosts that will only be NFS servers
# @param client1 Host that will only be a NFS client
# @param client2 Host that will only be a NFS client
#
# @param opts Hash of test options with the following keys:
#  * :base_hiera    - Base hieradata to be added to nfs-specific hieradata for
#                     all hosts
#  * :server_config - Hash of config to be applied to NFS server
#  * :mount1_config - Hash of config to be applied to NFS client1 for mounts
#                     to a server
#  * :mount2_config - Hash of config to be applied to NFS client2 for mounts
#                     to a server
#

shared_examples 'a multi-client NFS share' do |servers, client1, client2, opts|
  let(:exported_dir) { '/srv/nfs_share' }
  let(:file_basename) { 'test_file' }
  let(:file_search_string) { 'This is a test file' }

  servers.each do |server|
    context "with NFS server #{server}" do
      let(:server_opts) {{
        :is_server             => true,
        :is_client             => false,
        :nfsv3                 => opts[:server_config][:nfsv3],
        :exported_dir          => exported_dir,
        :exported_file         => File.join(exported_dir, file_basename),
        :exported_file_content => "#{file_search_string} from #{exported_dir}",
        :export_sec            => opts[:server_config][:export_sec],
        :export_insecure       => opts[:server_config][:export_insecure]
      }}

      let(:server_manifest) { create_export_manifest(server_opts) }

      context "as the NFS server #{server}" do
        it 'should ensure vagrant connectivity' do
          on(hosts, 'date')
        end

        it 'should apply server manifest to export' do
          server_hieradata = build_host_hiera(opts[:base_hiera], server_opts)
          set_hieradata_on(server, server_hieradata)
          print_test_config(server_hieradata, server_manifest)
          apply_manifest_on(server, server_manifest, :catch_failures => true)
        end

        it 'should be idempotent' do
          apply_manifest_on(server, server_manifest, :catch_changes => true)
        end

        it 'should export shared dir' do
          on(server, "exportfs -v | grep #{exported_dir}")
        end
      end

      {
        client1 => opts[:mount1_config],
        client2 => opts[:mount2_config]
      }.each do |client,config|

        context "as NFS client #{client}" do
          let(:client_opts) {{
            :is_server         => false,
            :is_client         => true,
            :nfsv3             => (config[:nfs_version] == 3),
            :mount_dir         => "/mnt/#{server.to_s}-#{File.basename(exported_dir)}",
            :mount_server_ip   => internal_network_info(server)[:ip],
            :mount_remote_dir  => exported_dir,
            :mount_nfs_version => config[:nfs_version],
            :mount_sec         => config[:sec],
            :mount_stunnel     => config[:stunnel]
          }}

          let(:client_manifest) { create_static_mount_manifest(client_opts) }

          it 'should apply client manifest to mount a dir from the server' do
            client_hieradata = build_host_hiera(opts[:base_hiera], client_opts)
            set_hieradata_on(client, client_hieradata)
            print_test_config(client_hieradata, client_manifest)
            apply_manifest_on(client, client_manifest, :catch_failures => true)
          end

          it 'should be idempotent' do
            apply_manifest_on(client, client_manifest, :catch_changes => true)
          end

          it "should mount NFS share from #{server}" do
           on(client, %(grep -q '#{file_search_string}' #{client_opts[:mount_dir]}/#{file_basename}))
          end
        end
      end

      context 'test clean up' do
        let(:mount_dir) { "/mnt/#{server.to_s}-#{File.basename(exported_dir)}" }
        it 'should remove mount as prep for next test' do
          # use puppet resource instead of simple umount, in order to remove
          # persistent mount configuration
          on([client1, client2], %{puppet resource mount #{mount_dir} ensure=absent})
          on([client1, client2], "rm -rf #{mount_dir}")
        end
      end
    end
  end
end
