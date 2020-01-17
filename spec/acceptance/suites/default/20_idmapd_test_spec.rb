require 'spec_helper_acceptance'

test_name 'nfs basic idmapd'

describe 'nfs basic idmapd' do

  servers = hosts_with_role( hosts, 'nfs_server' )
  clients = hosts_with_role( hosts, 'nfs_client' )

  base_hiera = {
    # Set us up for a NFSv4 with basic idmapd settings (default config)
    'simp_options::firewall'                => true,
    'simp_options::kerberos'                => false,
    'simp_options::stunnel'                 => false,
    'simp_options::tcpwrappers'             => false,
    'ssh::server::conf::permitrootlogin'    => true,
    'ssh::server::conf::authorizedkeysfile' => '.ssh/authorized_keys',

    # assuming all hosts configured to have same networks (public and private)
    'simp_options::trusted_nets'            => host_networks(hosts[0]),
    'nfs::idmapd'                           => true,

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

  context 'long running test' do
    it 'should ensure vagrant connectivity' do
      on(hosts, 'date')
    end
  end

  context 'with idmapd enabled' do
    opts = {
      :base_hiera      => base_hiera,
      :export_insecure => false,
      :nfs_sec         => 'sys',
      :nfsv3           => false,
      :verify_reboot   => true
    }

    it_behaves_like 'a NFS share using static mounts with distinct client/server roles', servers, clients, opts

    context 'idmapd config verification' do
      hosts.each do |host|
        it "should configure /etc/idmapd.conf on #{host}" do
          on(host, "grep 'file is managed by Puppet' /etc/idmapd.conf")
        end
      end

      clients.each do |client|
        it "should add nfsidmap to /etc/request-key.conf on #{client}" do
          on(client, "grep '/usr/sbin/nfsidmap' /etc/request-key.conf")
        end
      end
    end
  end
end
