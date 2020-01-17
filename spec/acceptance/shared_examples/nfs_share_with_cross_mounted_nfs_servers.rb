# Verify a complex configuration with 2 servers and an array of clients:
# * NFS server 1 mounts a directory from NFS server 2
# * NFS server 2 mounts a directory from NFS server 1
# * Each NFS client mounts directories from both NFS servers
#
# @param server1 Host that will only be a NFS server
# @param server2 Host that will only be a NFS server
# @param clients Array of Hosts that will only be NFS clients
#
# @param opts Hash of test options with the following keys:
#  * :base_hiera - Base hieradata to be added to nfs-specific hieradata for all
#                  hosts
#  * :server1_config - Hash of config to be applied to the first NFS server
#  * :server2_config - Hash of config to be applied to the second NFS server
#  * :client_config - Hash of config to be applied to each NFS client
#

shared_examples 'a NFS share with cross-mounted servers' do |server1, server2, clients, opts|
  file_basename =  'test_file'
  file_search_string = 'This is a test file'
  server1_opts = {
    :host                    => server1,
    :server_ip               => opts[:server1_config][:server_ip],
    :is_server               => true,
    :is_client               => true,
    :nfsv3                   => opts[:server1_config][:nfsv3],
    :nfsd_port               => opts[:server1_config][:nfsd_port],
    :stunnel_nfsd_port       => opts[:server1_config][:stunnel_nfsd_port],
    :exported_dir            => opts[:server1_config][:exported_dir],
    :exported_file           => File.join(opts[:server1_config][:exported_dir], file_basename),
    :exported_file_content   => "#{file_search_string} from #{opts[:server1_config][:exported_dir]}",
    :export_sec              => opts[:server1_config][:export_sec],
    :export_insecure         => opts[:server1_config][:export_insecure],
    # mount to server2
    :mount_server_name       => server2.to_s,
    :mount_dir               => "/mnt/#{server2.to_s}-#{File.basename(opts[:server2_config][:exported_dir])}",
    :mount_server_ip         => opts[:server2_config][:server_ip],
    :mount_remote_dir        => opts[:server2_config][:exported_dir],
    :mount_nfs_version       => opts[:server1_config][:mount_nfs_version],
    :mount_sec               => opts[:server1_config][:mount_sec],
    :mount_nfsd_port         => opts[:server2_config][:nfsd_port],
    :mount_stunnel_nfsd_port => opts[:server2_config][:stunnel_nfsd_port],
    :mount_stunnel           => opts[:server1_config][:mount_stunnel],
  }

  server2_opts = {
    :host                    => server2,
    :server_ip               => opts[:server2_config][:server_ip],
    :is_server               => true,
    :is_client               => true,
    :nfsv3                   => opts[:server2_config][:nfsv3],
    :nfsd_port               => opts[:server2_config][:nfsd_port],
    :stunnel_nfsd_port       => opts[:server2_config][:stunnel_nfsd_port],
    :exported_dir            => opts[:server2_config][:exported_dir],
    :exported_file           => File.join(opts[:server2_config][:exported_dir], file_basename),
    :exported_file_content   => "#{file_search_string} from #{opts[:server2_config][:exported_dir]}",
    :export_sec              => opts[:server2_config][:export_sec],
    :export_insecure         => opts[:server2_config][:export_insecure],
    # mount to server1
    :mount_server_name       => server1.to_s,
    :mount_dir               => "/mnt/#{server1.to_s}-#{File.basename(opts[:server1_config][:exported_dir])}",
    :mount_server_ip         => opts[:server1_config][:server_ip],
    :mount_remote_dir        => opts[:server1_config][:exported_dir],
    :mount_nfs_version       => opts[:server2_config][:mount_nfs_version],
    :mount_sec               => opts[:server2_config][:mount_sec],
    :mount_nfsd_port         => opts[:server1_config][:nfsd_port],
    :mount_stunnel_nfsd_port => opts[:server1_config][:stunnel_nfsd_port],
    :mount_stunnel           => opts[:server2_config][:mount_stunnel],
  }

  # Just do the exports first, so we can then apply a manifest that exports
  # and mounts and have it succeed next
  context 'server initial exports' do
    [ server1_opts, server2_opts].each do |srv_opts|
      context "as NFS server #{srv_opts[:host]}" do
        let(:server) { srv_opts[:host] }
        let(:server_manifest) {
          create_export_manifest(srv_opts)
        }

        it 'should apply server manifest to export' do
          server_hieradata = build_host_hiera(opts[:base_hiera], srv_opts)
          set_hieradata_on(server, server_hieradata)
          print_test_config(server_hieradata, server_manifest)
          apply_manifest_on(server, server_manifest, :catch_failures => true)
        end

        it 'should be idempotent' do
          apply_manifest_on(server, server_manifest, :catch_changes => true)
        end

        it 'should export shared dir' do
          on(server, 'exportfs -v')
          on(server, "exportfs -v | grep #{srv_opts[:exported_dir]}")
        end
      end
    end
  end

  context 'vagrant connectivity' do
    it 'should ensure vagrant connectivity' do
      on(hosts, 'date')
    end
  end

  context 'server exports and mounts' do
    [ server1_opts, server2_opts].each do |srv_opts|
      context "as NFS server #{srv_opts[:host]}" do
        let(:server) { srv_opts[:host] }
        let(:server_manifest) {
          [
            create_export_manifest(srv_opts),
            '',
            create_static_mount_manifest(srv_opts)
          ].join("\n")
        }

        it 'should apply server manifest to export and mount' do
          server_hieradata = build_host_hiera(opts[:base_hiera], srv_opts)
          set_hieradata_on(server, server_hieradata)
          print_test_config(server_hieradata, server_manifest)
          apply_manifest_on(server, server_manifest, :catch_failures => true)
        end

        it 'should be idempotent' do
          apply_manifest_on(server, server_manifest, :catch_changes => true)
        end

        it 'should export shared dir' do
          on(server, 'exportfs -v')
          on(server, "exportfs -v | grep #{srv_opts[:exported_dir]}")
        end

        it "should mount NFS share from #{srv_opts[:mount_server_name]}" do
          on(server, "mount | grep #{srv_opts[:mount_dir]}")
          on(server, %(grep -q '#{file_search_string}' #{srv_opts[:mount_dir]}/#{file_basename}))
        end
      end
    end
  end

  clients_cleanup_opts = []
  clients.each_index do |index|
    client_opts = {
      :host       => clients[index],
      :is_server  => false,
      :is_client  => true,
      :nfsv3      => opts[:client_config][:nfsv3],
      :mounts     => [
        { # mount to server 1
          :mount_dir               => "/mnt/#{server1.to_s}-#{File.basename(opts[:server1_config][:exported_dir])}",
          :mount_server_name       => server1.to_s,
          :mount_server_ip         => opts[:server1_config][:server_ip],
          :mount_remote_dir        => opts[:server1_config][:exported_dir],
          :mount_nfs_version       => (opts[:client_config][:mount_nfs_version] ? opts[:client_config][:mount_nfs_version][0] : nil),
          :mount_sec               => (opts[:client_config][:mount_sec] ? opts[:client_config][:mount_sec][0] : nil),
          :mount_nfsd_port         => opts[:server1_config][:nfsd_port],
          :mount_stunnel_nfsd_port => opts[:server1_config][:stunnel_nfsd_port],
          :mount_stunnel           => (opts[:client_config][:mount_stunnel] ? opts[:client_config][:mount_stunnel][0] : nil)
        },
        { # mount to server 2
          :mount_dir               => "/mnt/#{server2.to_s}-#{File.basename(opts[:server2_config][:exported_dir])}",
          :mount_server_name       => server2.to_s,
          :mount_server_ip         => opts[:server2_config][:server_ip],
          :mount_remote_dir        => opts[:server2_config][:exported_dir],
          :mount_nfs_version       => (opts[:client_config][:mount_nfs_version] ? opts[:client_config][:mount_nfs_version][1] : nil),
          :mount_sec               => (opts[:client_config][:mount_sec] ? opts[:client_config][:mount_sec][1] : nil),
          :mount_nfsd_port         => opts[:server2_config][:nfsd_port],
          :mount_stunnel_nfsd_port => opts[:server2_config][:stunnel_nfsd_port],
          :mount_stunnel           => (opts[:client_config][:mount_stunnel] ? opts[:client_config][:mount_stunnel][1] : nil)
        }
      ]
    }

    clients_cleanup_opts << { :host => clients[index], :mount_dir => client_opts[:mounts][0][:mount_dir] }
    clients_cleanup_opts << { :host => clients[index], :mount_dir => client_opts[:mounts][1][:mount_dir] }

    context "as a NFS client #{clients[index]} using NFS servers #{server1} and #{server2}" do
      let(:client) { clients[index] }
      let(:client_manifest) {
        [
          create_static_mount_manifest(client_opts[:mounts][0]),
          '',
          create_static_mount_manifest(client_opts[:mounts][1])
        ].join("\n")
      }

      it 'should ensure vagrant connectivity' do
        on(hosts, 'date')
      end

      it 'should apply client manifest to mount a dir from each server' do
        client_hieradata = build_host_hiera(opts[:base_hiera], client_opts)
        set_hieradata_on(client, client_hieradata)
        print_test_config(client_hieradata, client_manifest)
        apply_manifest_on(client, client_manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(client, client_manifest, :catch_changes => true)
        on(client, 'mount')
      end

      client_opts[:mounts].each do |mount_opts|
        it "should mount NFS share from #{mount_opts[:mount_server_name]}" do
          on(client, "mount | grep #{mount_opts[:mount_dir]}")
          on(client, %(grep -q '#{file_search_string}' #{mount_opts[:mount_dir]}/#{file_basename}))
        end
      end
    end
  end

  context 'cleanup' do
    ([ server1_opts, server2_opts] + clients_cleanup_opts).each do |host_opts|
      let(:host) { host_opts[:host] }
      it 'should remove mount as prep for next test' do
        # use puppet resource instead of simple umount, in order to remove
        # persistent mount configuration
        on(host, %{puppet resource mount #{host_opts[:mount_dir]} ensure=absent})
        on(host, "rm -rf #{host_opts[:mount_dir]}")
      end
    end
  end
end
