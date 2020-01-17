require 'spec_helper_acceptance'

test_name 'cross-mounted NFS servers plus clients'

# Tests complex configuration of 2 servers and an array of clients:
# * NFS server 1 mounts a directory from NFS server 2
# * NFS server 2 mounts a directory from NFS server 1
# * Each NFS client mounts directories from both NFS servers

describe 'cross-mounted NFS servers plus clients' do

  servers = hosts_with_role( hosts, 'nfs_server' )

  if servers.size < 2
    fail("#{__FILE__} requires at least 2 hosts with role 'nfs_server'")
  end

  server1 = servers[0]
  server2 = servers[1]
  clients = hosts_with_role( hosts, 'nfs_client' )

  base_hiera = {
    'simp_options::firewall'                => true,
    'simp_options::kerberos'                => false,
    'simp_options::stunnel'                 => false,
    'simp_options::tcpwrappers'             => false,
    'ssh::server::conf::permitrootlogin'    => true,
    'ssh::server::conf::authorizedkeysfile' => '.ssh/authorized_keys',

    # assuming all hosts configured to have same networks (public and private)
    'simp_options::trusted_nets'            => host_networks(hosts[0]),

    # make sure we are using iptables and not nftables because nftables
    # core dumps with rules from the nfs module
    'firewalld::firewall_backend'           => 'iptables'
  }

  # FIXME.  Remove this when we can reliably configure firewalld backend to
  # be iptables.
  # Workaround duplicated so can run this test file by itself.
  context 'work around firewalld ordering issue' do
    it_behaves_like 'a firewalld fixer', hosts
  end

  context 'NFSv4 cross mounts' do
    opts = {
      :base_hiera => base_hiera,
      :server1_config => {
        :server_ip         => internal_network_info(server1)[:ip],
        :exported_dir      => '/srv/home',
        :export_insecure   => false,
        :export_sec        => 'sys',
        :mount_nfs_version => 4,
        :mount_sec         => 'sys',
        :mount_stunnel     => false
      },
      :server2_config => {
        :server_ip         => internal_network_info(server2)[:ip],
        :exported_dir      => '/srv/apps',
        :export_insecure   => false,
        :export_sec        => 'sys',
        :mount_nfs_version => 4,
        :mount_sec         => 'sys',
        :mount_stunnel     => false
      },
      # applies to all clients
      :client_config => {
        # index 0 => server1 mount, index 1 => server 2 mount
        :mount_nfs_version => [4, 4],
        :mount_sec         => ['sys', 'sys'],
        :mount_stunnel     => [false, false]
      }
    }

    it_behaves_like 'a NFS share with cross-mounted servers',
      server1, server2, clients, opts
  end
end
