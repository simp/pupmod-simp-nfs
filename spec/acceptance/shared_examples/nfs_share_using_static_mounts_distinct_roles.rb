# @param servers Array of Hosts that will only be NFS servers
# @param clients Array of Hosts that will only be NFS clients
#
# @param opts Hash of test options with the following keys:
#  * :base_hiera    - Base hieradata to be added to nfs-specific hieradata
#  * :server_custom - Additional content to be added to the NFS server manifest
#  * :client_custom - Additional content to be added to the NFS client manifest
#  * :nfsv3         - Whether this is testing NFSv3.  When true, NFSv3 will be
#                     enabled (server + client) and used in the client mount
#  * :nfs_sec       - NFS security option to use in both the server export and
#                     the client mount
#  * :export_insecure - insecure setting for NFS export
#  * :verify_reboot - Whether to verify idempotency and mount functionality
#                     after individually rebooting the client and server
#                     in each test pair
#
shared_examples 'a NFS share using static mounts with distinct client/server roles' do |servers, clients, opts|
  let(:exported_dir) { '/srv/nfs_share' }
  let(:file_basename) { 'test_file' }
  let(:file_search_string) { 'This is a test file' }

  let(:server_opts) do
    {
      is_server: true,
      is_client: false,
      nfsv3: opts[:nfsv3],
      exported_dir: exported_dir,
      exported_file: File.join(exported_dir, file_basename),
      exported_file_content: "#{file_search_string} from #{exported_dir}",
      export_sec: opts[:nfs_sec],
      export_insecure: opts[:export_insecure],
      server_custom: opts[:server_custom],
    }
  end

  let(:server_manifest) { create_export_manifest(server_opts) }

  servers.each do |server|
    context "as just a NFS server #{server}" do
      it 'ensures vagrant connectivity' do
        on(hosts, 'date')
      end

      it 'applies server manifest to export' do
        server_hieradata = build_host_hiera(opts[:base_hiera], server_opts)
        set_hieradata_on(server, server_hieradata)
        print_test_config(server_hieradata, server_manifest)
        apply_manifest_on(server, server_manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(server, server_manifest, catch_changes: true)
      end

      it 'exports shared dir' do
        on(server, 'exportfs -v')
        on(server, "exportfs -v | grep #{exported_dir}")
      end
    end
  end

  clients.each do |client|
    servers.each do |server|
      context "as just a NFS client #{client} using NFS server #{server}" do
        let(:client_opts) do
          {
            is_server: false,
            is_client: true,
            nfsv3: opts[:nfsv3],
            mount_dir: "/mnt/#{server}-#{File.basename(exported_dir)}",
            mount_server_ip: internal_network_info(server)[:ip],
            mount_remote_dir: exported_dir,
            mount_nfs_version: (opts[:nfsv3] ? 3 : 4),
            mount_sec: opts[:nfs_sec],
          }
        end

        let(:client_manifest) do
          <<~EOM
            #{create_static_mount_manifest(client_opts)}

            #{opts[:client_custom]}
          EOM
        end

        it "applies client manifest to mount dir from #{server}" do
          client_hieradata = build_host_hiera(opts[:base_hiera], client_opts)
          set_hieradata_on(client, client_hieradata)
          print_test_config(client_hieradata, client_manifest)
          apply_manifest_on(client, client_manifest, catch_failures: true)
        end

        it 'is idempotent' do
          apply_manifest_on(client, client_manifest, catch_changes: true)
        end

        # rubocop:disable RSpec/RepeatedExample
        it 'mounts NFS share' do
          on(client, %(grep -q '#{file_search_string}' #{client_opts[:mount_dir]}/#{file_basename}))
        end
        # rubocop:enable RSpec/RepeatedExample

        if opts[:nfsv3]
          # Want to verify the NLM ports are correctly configured.  According
          # to nfs man page, NLM supports advisory file locks only and the
          # client converts file locks obtained via flock to advisory locks.
          # So, we can use flock in this test.
          #
          # If flock hangs, we have a NLM connectivity problem. Ideally, we would
          # want an immediate indication of a connectivity issues via flock.
          # Unfortunately, even the --nonblock flock option simply hangs when we
          # have communication problem. So, we will timeout to detect communication
          # problems instead.
          it 'communicates lock status with NFS server' do
            require 'timeout'

            begin
              # After the NFS daemon restarts, it waits grace-time seconds before
              # allowing new file open requests (NFSv4) or file locks via NLM
              # (NFSv3). This is intended to give the client time to recover
              # state. The default grace-time is 90 seconds
              nfsd_grace_time = 90
              lock_seconds = 1
              timeout_seconds = nfsd_grace_time + lock_seconds + 2
              Timeout.timeout(timeout_seconds) do
                on(client, "date; flock  #{client_opts[:mount_dir]}/#{file_basename} -c 'sleep #{lock_seconds}'; date")
              end
            rescue Timeout::Error
              raise('Problem with NFSv3 connectivity during file lock')
            end
          end
        end

        if opts[:verify_reboot]
          it 'ensures vagrant connectivity' do
            on(hosts, 'date')
          end

          unless opts[:nfsv3]
            # The nfsv4 kernel module is only automatically loaded when a NFSv4
            # mount is executed. In the NFSv3 test, we only mount using NFSv3.
            # So, after reboot, the nfsv4 kernel module will not be loaded.
            # However, since nfs::client::config pre-emptively loads the nfsv4
            # kernel module (necessary to ensure config initially prior to
            # reboot), applying the client manifest in the absence of NFSv4
            # mount will cause the Exec[modprove_nfsv4] to be executed.
            it 'client manifest should be idempotent after reboot' do
              client.reboot
              wait_for_reboot_hack(client)
              apply_manifest_on(client, client_manifest, catch_changes: true)
            end
          end

          # rubocop:disable RSpec/RepeatedExample
          it 'mount should be re-established after client reboot' do
            on(client, %(grep -q '#{file_search_string}' #{client_opts[:mount_dir]}/#{file_basename}))
          end

          it 'server manifest should be idempotent after reboot' do
            server.reboot
            wait_for_reboot_hack(server)
            apply_manifest_on(server, server_manifest, catch_changes: true)
          end

          it 'mount should be re-established after server reboot' do
            on(client, %(grep -q '#{file_search_string}' #{client_opts[:mount_dir]}/#{file_basename}))
          end
          # rubocop:enable RSpec/RepeatedExample
        end

        it 'removes mount as prep for next test' do
          # use puppet resource instead of simple umount, in order to remove
          # persistent mount configuration
          on(client, %(puppet resource mount #{client_opts[:mount_dir]} ensure=absent))
          on(client, "rm -rf #{client_opts[:mount_dir]}")
        end
      end
    end
  end
end
