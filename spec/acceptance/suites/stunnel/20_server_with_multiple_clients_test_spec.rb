require 'spec_helper_acceptance'

test_name 'nfs server with multiple clients'

#################################################################
# IMPORTANT:  See discussion of nfs::server::export::insecure in
# 00_stunnel_test_spec.rb.
#################################################################

# Tests stunneling between an individual NFS server and 2 NFS clients.
# Verifies server can support a mix of NFSv4 (stunneled) and NFSv3 (direct)
# client mounts of the same exported filesystem.
describe 'nfs server with multiple clients' do
  clients = hosts_with_role(hosts, 'nfs_client')

  if clients.size < 2
    raise("#{__FILE__} requires at least 2 hosts with role 'nfs_client'")
  end

  client1 = clients[0]
  client2 = clients[1]
  servers = hosts_with_role(hosts, 'nfs_server')

  base_hiera = {
    # Set us up for a stunneled NFS with firewall
    'simp_options::audit'                   => false,
    'simp_options::firewall'                => true,
    'simp_options::haveged'                 => true,
    'simp_options::kerberos'                => false,
    'simp_options::pki'                     => true,
    'simp_options::pki::source'             => '/etc/pki/simp-testing/pki',

    # Will only apply to NFSv4 connections
    'simp_options::stunnel'                 => true,

    'simp_options::tcpwrappers'             => false,
    'ssh::server::conf::permitrootlogin'    => true,
    'ssh::server::conf::authorizedkeysfile' => '.ssh/authorized_keys',

    # This assumes all hosts configured to have same networks (public and private)
    'simp_options::trusted_nets'            => host_networks(hosts[0]),

    # There is no DNS so we need to eliminate verification
    'nfs::stunnel_verify'                   => 0,

    # make sure we are using iptables and not nftables because nftables
    # core dumps with rules from the nfs module
    'firewalld::firewall_backend'           => 'iptables'
  }

  context 'server exporting to 2 NFSv4 clients, both via stunnel' do
    opts = {
      base_hiera: base_hiera,
      server_config: {
        export_insecure: true, # server allows mount via NFSv4 stunnel
        export_sec: 'sys' # server export NFS sec setting
      },
      mount1_config: {
        nfs_version: 4, # client1 mount with NFSv4
        sec: 'sys', # client1 mount NFS sec setting
        stunnel: true # client1 mount enable stunnel
      },
      mount2_config: {
        nfs_version: 4, # client2 mount with NFSv4
        sec: 'sys', # client2 mount NFS sec setting
        stunnel: true # client1 mount enable stunnel
      },
    }

    it_behaves_like 'a multi-client NFS share', servers, client1, client2, opts
  end

  context 'client mounting from 1 NFSv4 server via stunnel and 1 NFSv3 server directly' do
    opts = {
      base_hiera: base_hiera,
      server_config: {
        nfsv3: true, # NFSv3 and NFSv4
        export_insecure: true, # server allows mount via NFSv4 stunnel
        export_sec: 'sys' # server export NFS sec setting
      },
      mount1_config: {
        nfs_version: 4, # client1 mount with NFSv4
        sec: 'sys', # client1 mount NFS sec setting
        stunnel: nil # client1 mount, stunnel enabled by default
      },
      mount2_config: {
        nfs_version: 3, # client2 mount with NFSv3
        sec: 'sys', # client2 mount NFS sec setting
        stunnel: nil # client2 mount, stunnel automatically disabled
      }
    }

    it_behaves_like 'a multi-client NFS share', servers, client1, client2, opts
  end

  context 'client mounting from 2 NFSv3 servers directly' do
    opts = {
      base_hiera: base_hiera,
      server_config: {
        nfsv3: true, # NFSv3 and NFSv4
        export_insecure: true, # server allows mount via NFSv4 stunnel
        export_sec: 'sys' # server export NFS sec setting
      },
      mount1_config: {
        nfs_version: 3, # client1 mount with NFSv3
        sec: 'sys', # client1 mount NFS sec setting
        stunnel: false # client2 mount disable stunnel
      },
      mount2_config: {
        nfs_version: 3, # client2 mount with NFSv3
        sec: 'sys', # client2 mount NFS sec setting
        stunnel: false # client2 mount disable stunnel
      }
    }

    it_behaves_like 'a multi-client NFS share', servers, client1, client2, opts
  end
end
