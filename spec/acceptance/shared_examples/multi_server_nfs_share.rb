# Verify a NFS client can mount directories from two NFS servers simultaneously.
#
#   client mount ----> server1 exported dir
#               \
#                ----> server2 exported dir
#
# This test is most useful for verifying a client supports simultaneous
# stunneled and non-stunneled connections to different servers.
#
# Characteristics of the server capabilities, server exports and clients mounts
# (e.g., stunnel, NFSv4 or NFSv3, insecure export) are controlled by opts.
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

shared_examples 'a multi-server NFS share' do |server1, server2, clients, opts|
  file_basename =  'test_file'
  file_search_string = 'This is a test file'
  server1_opts = {
    host: server1,
    is_server: true,
    is_client: false,
    nfsv3: opts[:server1_config][:nfsv3],
    nfsd_port: opts[:server1_config][:nfsd_port],
    stunnel_nfsd_port: opts[:server1_config][:stunnel_nfsd_port],
    exported_dir: opts[:server1_config][:exported_dir],
    exported_file: File.join(opts[:server1_config][:exported_dir], file_basename),
    exported_file_content: "#{file_search_string} from #{opts[:server1_config][:exported_dir]}",
    export_sec: opts[:server1_config][:export_sec],
    export_insecure: opts[:server1_config][:export_insecure],
  }

  server2_opts = {
    host: server2,
    is_server: true,
    is_client: false,
    nfsv3: opts[:server2_config][:nfsv3],
    nfsd_port: opts[:server2_config][:nfsd_port],
    stunnel_nfsd_port: opts[:server2_config][:stunnel_nfsd_port],
    exported_dir: opts[:server2_config][:exported_dir],
    exported_file: File.join(opts[:server2_config][:exported_dir], file_basename),
    exported_file_content: "#{file_search_string} from #{opts[:server2_config][:exported_dir]}",
    export_sec: opts[:server2_config][:export_sec],
    export_insecure: opts[:server2_config][:export_insecure],
  }

  context 'server exports' do
    [ server1_opts, server2_opts].each do |srv_opts|
      context "as NFS server #{srv_opts[:host]}" do
        let(:server) { srv_opts[:host] }
        let(:server_manifest) do
          create_export_manifest(srv_opts)
        end

        it 'applies server manifest to export' do
          server_hieradata = build_host_hiera(opts[:base_hiera], srv_opts)
          set_hieradata_on(server, server_hieradata)
          print_test_config(server_hieradata, server_manifest)
          apply_manifest_on(server, server_manifest, catch_failures: true)
        end

        it 'is idempotent' do
          apply_manifest_on(server, server_manifest, catch_changes: true)
        end

        it 'exports shared dir' do
          on(server, 'exportfs -v')
          on(server, "exportfs -v | grep #{srv_opts[:exported_dir]}")
        end
      end
    end
  end

  context 'vagrant connectivity' do
    it 'ensures vagrant connectivity' do
      on(hosts, 'date')
    end
  end

  clients.each_index do |index|
    client_opts = {
      host: clients[index],
      is_server: false,
      is_client: true,
      nfsv3: opts[:client_config][:nfsv3],
      mounts: [
        { # mount to server 1
          mount_dir: "/mnt/#{server1}-#{File.basename(opts[:server1_config][:exported_dir])}",
          mount_server_name: server1.to_s,
          mount_server_ip: opts[:server1_config][:server_ip],
          mount_remote_dir: opts[:server1_config][:exported_dir],
          mount_nfs_version: (opts[:client_config][:mount_nfs_version] ? opts[:client_config][:mount_nfs_version][0] : nil),
          mount_sec: (opts[:client_config][:mount_sec] ? opts[:client_config][:mount_sec][0] : nil),
          mount_nfsd_port: opts[:server1_config][:nfsd_port],
          mount_stunnel_nfsd_port: opts[:server1_config][:stunnel_nfsd_port],
          mount_stunnel: (opts[:client_config][:mount_stunnel] ? opts[:client_config][:mount_stunnel][0] : nil),
        },
        { # mount to server 2
          mount_dir: "/mnt/#{server2}-#{File.basename(opts[:server2_config][:exported_dir])}",
          mount_server_name: server2.to_s,
          mount_server_ip: opts[:server2_config][:server_ip],
          mount_remote_dir: opts[:server2_config][:exported_dir],
          mount_nfs_version: (opts[:client_config][:mount_nfs_version] ? opts[:client_config][:mount_nfs_version][1] : nil),
          mount_sec: (opts[:client_config][:mount_sec] ? opts[:client_config][:mount_sec][1] : nil),
          mount_nfsd_port: opts[:server2_config][:nfsd_port],
          mount_stunnel_nfsd_port: opts[:server2_config][:stunnel_nfsd_port],
          mount_stunnel: (opts[:client_config][:mount_stunnel] ? opts[:client_config][:mount_stunnel][1] : nil),
        },
      ],
    }

    context "as a NFS client #{clients[index]} using NFS servers #{server1} and #{server2}" do
      let(:client) { clients[index] }
      let(:client_manifest) do
        [
          create_static_mount_manifest(client_opts[:mounts][0]),
          '',
          create_static_mount_manifest(client_opts[:mounts][1]),
        ].join("\n")
      end

      it 'ensures vagrant connectivity' do
        on(hosts, 'date')
      end

      it 'applies client manifest to mount a dir from each server' do
        client_hieradata = build_host_hiera(opts[:base_hiera], client_opts)
        set_hieradata_on(client, client_hieradata)
        print_test_config(client_hieradata, client_manifest)
        apply_manifest_on(client, client_manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(client, client_manifest, catch_changes: true)
        on(client, 'mount')
      end

      client_opts[:mounts].each do |mount_opts|
        it "mounts NFS share from #{mount_opts[:mount_server_name]}" do
          on(client, "mount | grep #{mount_opts[:mount_dir]}")
          on(client, %(grep -q '#{file_search_string}' #{mount_opts[:mount_dir]}/#{file_basename}))
        end
      end

      client_opts[:mounts].each do |mount_opts|
        it 'removes mount as prep for next test' do
          # use puppet resource instead of simple umount, in order to remove
          # persistent mount configuration
          on(client, %(puppet resource mount #{mount_opts[:mount_dir]} ensure=absent))
          on(client, "rm -rf #{mount_opts[:mount_dir]}")
        end
      end
    end
  end
end
