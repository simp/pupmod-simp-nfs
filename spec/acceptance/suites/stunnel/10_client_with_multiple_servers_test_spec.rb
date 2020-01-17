require 'spec_helper_acceptance'

test_name 'nfs client with multiple servers'

#################################################################
# IMPORTANT:  See discussion of nfs::server::export::insecure in
# 00_stunnel_test_spec.rb.
#################################################################

# Tests stunneling between an individual NFS client and 2 NFS server.
# Verifies client can have a mix of NFSv4 (stunneled) and NFSv3 (direct)
# mounts.

describe 'nfs client with multiple servers' do

  servers = hosts_with_role( hosts, 'nfs_server' )

  if servers.size < 2
    fail("#{__FILE__} requires at least 2 hosts with role 'nfs_server'")
  end

  server1 = servers[0]
  server2 = servers[1]
  clients = hosts_with_role( hosts, 'nfs_client' )

  base_hiera = {
    # Set us up for a stunneled NFS with firewall
    'simp_options::audit'                   => false,
    'simp_options::firewall'                => true,
    'simp_options::haveged'                 => true,
    'simp_options::kerberos'                => false,
    'simp_options::pki'                     => true,
    'simp_options::pki::source'             => '/etc/pki/simp-testing/pki',
    # will only apply to NFSv4 connections
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

  # FIXME.  Remove this when we can reliably configure firewalld backend to
  # be iptables.
  # Workaround duplicated so can run this test file by itself.
  context 'work around firewalld ordering issue' do
    it_behaves_like 'a firewalld fixer', hosts
  end

  context 'client mounting from 2 NFSv4 servers, both via stunnel' do
    opts = {
      :base_hiera => base_hiera,
      :server1_config => {
        :server_ip         => internal_network_info(server1)[:ip],
        :nfsv3             => false, # NFSv4 only
        :nfsd_port         => 2049,
        :stunnel_nfsd_port => 20490,
        :exported_dir      => '/srv/home',
        :export_insecure   => true,
        :export_sec        => 'sys',
      },
      :server2_config => {
        :server_ip         => internal_network_info(server2)[:ip],
        :nfsv3             => false, # NFSv4 only
        :nfsd_port         => 2150,  # avoid port conflict with server1
        :stunnel_nfsd_port => 21500,
        :exported_dir      => '/srv/apps',
        :export_insecure   => true,
        :export_sec        => 'sys',
      },
      # applies to all clients
      :client_config => {
        :nfsv3             => false, # NFSv4 only
        # index 0 => server1 mount, index 1 => server 2 mount
        :mount_nfs_version => [4, 4],
        :mount_sec         => ['sys', 'sys'],
        :mount_stunnel     => [nil, nil] # use default of true
      }
    }

    it_behaves_like 'a multi-server NFS share', server1, server2, clients, opts
  end

  context 'client mounting from 1 NFSv4 server via stunnel and 1 NFSv3 server directly' do
    opts = {
      :base_hiera => base_hiera,
      :server1_config => {
        :server_ip         => internal_network_info(server1)[:ip],
        :nfsv3             => false, # NFSv4 only
        :nfsd_port         => 2049,
        :stunnel_nfsd_port => 20490,
        :exported_dir      => '/srv/home',
        :export_insecure   => true,
        :export_sec        => 'sys',
      },
      :server2_config => {
        :server_ip         => internal_network_info(server2)[:ip],
        :nfsv3             => true, # NFSv3 and NFSv4
        :nfsd_port         => 2150,  # avoid port conflict with server1
        :stunnel_nfsd_port => 21500, #
        :exported_dir      => '/srv/apps',
        :export_insecure   => true,
        :export_sec        => 'sys',
      },
      # applies to all clients
      :client_config => {
        :nfsv3             => true, # NFSv3 and NFSv4
        # index 0 => server1 mount, index 1 => server 2 mount
        :mount_nfs_version => [4, 3],
        :mount_sec         => ['sys', 'sys'],
        :mount_stunnel     => [true, false]
      }
    }

    it_behaves_like 'a multi-server NFS share', server1, server2, clients, opts
  end

  context 'client mounting from 2 NFSv3 servers directly' do
    opts = {
      :base_hiera => base_hiera,
      :server1_config => {
        :server_ip         => internal_network_info(server1)[:ip],
        :nfsv3             => true,  # NFSv3 and NFSv4
        :nfsd_port         => 2049,
        :stunnel_nfsd_port => 20490,
        :exported_dir      => '/srv/home',
        :export_insecure   => true,
        :export_sec        => 'sys',
      },
      :server2_config => {
        :server_ip         => internal_network_info(server2)[:ip],
        :nfsv3             => true,  # NFSv3 and NFSv4
        :nfsd_port         => 2150,  # avoid port conflict with server1
        :stunnel_nfsd_port => 21500,
        :exported_dir      => '/srv/apps',
        :export_insecure   => true,
        :export_sec        => 'sys',
      },
      # applies to all clients
      :client_config => {
        :nfsv3             => true, # NFSv3 and NFSv4
        # index 0 => server1 mount, index 1 => server 2 mount
        :mount_nfs_version => [3, 3],
        :mount_sec         => ['sys', 'sys'],
        :mount_stunnel     => [false, false]
      }
    }

    it_behaves_like 'a multi-server NFS share', server1, server2, clients, opts
  end
end
