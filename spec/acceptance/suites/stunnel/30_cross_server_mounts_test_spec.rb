require 'spec_helper_acceptance'

test_name 'cross-mounted NFS servers plus clients'

#################################################################
# IMPORTANT:  See discussion of nfs::server::export::insecure in
# 00_stunnel_test_spec.rb.
#################################################################

# Tests complex configuration of 2 servers and an array of clients:
# * NFS server 1 mounts a directory from NFS server 2
# * NFS server 2 mounts a directory from NFS server 1
# * Each NFS client mounts directories from both NFS servers
#

describe 'cross-mounted NFS servers plus clients' do

  servers = hosts_with_role( hosts, 'nfs_server' )

  if servers.size < 2
    fail("#{__FILE__} requires at least 2 hosts with role 'nfs_server'")
  end

  server1 = servers[0]
  server2 = servers[1]
  clients = hosts_with_role( hosts, 'nfs_client' )

  base_hiera = {
    'simp_options::audit'                   => false,
    'simp_options::firewall'                => true,
    'simp_options::haveged'                 => true,
    'simp_options::kerberos'                => false,
    'simp_options::pki'                     => true,
    'simp_options::pki::source'             => '/etc/pki/simp-testing/pki',
    'simp_options::stunnel'                 => true,
    'simp_options::tcpwrappers'             => false,
    'ssh::server::conf::permitrootlogin'    => true,
    'ssh::server::conf::authorizedkeysfile' => '.ssh/authorized_keys',

    # assuming all hosts configured to have same networks (public and private)
    'simp_options::trusted_nets'            => host_networks(hosts[0]),

    # There is no DNS so we need to eliminate verification
    'nfs::stunnel_verify'                   => 0,

    # make sure we are using iptables and not nftables because nftables
    # core dumps with rules from the nfs module
    'firewalld::firewall_backend'           => 'iptables'
  }

  context 'NFSv4 cross mounts with stunnel' do
    opts = {
      :base_hiera => base_hiera,
      :server1_config => {
        :server_ip         => internal_network_info(server1)[:ip],
        :nfsd_port         => 2049,
        :stunnel_nfsd_port => 20490,
        :exported_dir      => '/srv/home',
        :export_insecure   => true,
        :export_sec        => 'sys',
        :mount_nfs_version => 4,
        :mount_sec         => 'sys',
        :mount_stunnel     => true
      },
      :server2_config => {
        :server_ip         => internal_network_info(server2)[:ip],
        :nfsd_port         => 2150,  # avoid port conflict with server1
        :stunnel_nfsd_port => 21500,
        :exported_dir      => '/srv/apps',
        :export_insecure   => true,
        :export_sec        => 'sys',
        :mount_nfs_version => 4,
        :mount_sec         => 'sys',
        :mount_stunnel     => true
      },
      # applies to all clients
      :client_config => {
        # index 0 => server1 mount, index 1 => server 2 mount
        :mount_nfs_version => [4, 4],
        :mount_sec         => ['sys', 'sys'],
        :mount_stunnel     => [true, true]
      }
    }

    it_behaves_like 'a NFS share with cross-mounted servers',
      server1, server2, clients, opts
  end
end
