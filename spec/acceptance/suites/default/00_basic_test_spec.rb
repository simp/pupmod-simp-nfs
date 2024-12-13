require 'spec_helper_acceptance'

test_name 'nfs basic'

describe 'nfs basic' do
  servers = hosts_with_role(hosts, 'nfs_server')
  servers_with_client = hosts_with_role(hosts, 'nfs_server_and_client')
  servers_tcpwrappers = servers.select { |server| server.name.include?('el7') }

  clients = hosts_with_role(hosts, 'nfs_client')
  clients_tcpwrappers = clients.select { |client| client.name.include?('el7') }

  base_hiera = {
    # Set us up for a basic NFS (firewall-only)
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

  context 'with firewall only' do
    context 'NFSv4 with firewall' do
      opts = {
        base_hiera: base_hiera,
        export_insecure: false,
        nfs_sec: 'sys',
        nfsv3: false,
        mount_autodetect_remote: [ true, false ],
        verify_reboot: true
      }

      it_behaves_like 'a NFS share using static mounts with distinct client/server roles', servers, clients, opts
      it_behaves_like 'a NFS share using static mounts with combined client/server roles', servers_with_client, opts
      it_behaves_like 'a NFS share using autofs with distinct client/server roles', servers, clients, opts
    end

    context 'NFSv3 with firewall' do
      opts = {
        base_hiera: base_hiera,
        export_insecure: false,
        nfs_sec: 'sys',
        nfsv3: true,
        mount_autodetect_remote: [ true, false ], # used in combined client/server test
        verify_reboot: true
      }

      it_behaves_like 'a NFS share using static mounts with distinct client/server roles', servers, clients, opts
      it_behaves_like 'a NFS share using static mounts with combined client/server roles', servers_with_client, opts
      it_behaves_like 'a NFS share using autofs with distinct client/server roles', servers, clients, opts
    end
  end

  context 'long running test' do
    it 'ensures vagrant connectivity' do
      on(hosts, 'date')
    end
  end

  context 'with firewall and tcpwrappers' do
    tcpwrappers_hiera = {
      'simp_options::tcpwrappers' => true,

      # use as much TCP as possible for NFS
      'nfs::custom_nfs_conf_opts' => {
        'nfsd' => {
          'tcp' => true,
          'udp' => false
        }
      }
    }

    context 'NFSv4 with firewall and tcpwrappers' do
      opts = {
        base_hiera: base_hiera.merge(tcpwrappers_hiera),
        export_insecure: false,
        nfs_sec: 'sys',
        nfsv3: false,
        verify_reboot: false
      }

      it_behaves_like 'a NFS share using static mounts with distinct client/server roles',
        servers_tcpwrappers, clients_tcpwrappers, opts

      it_behaves_like 'a NFS share using autofs with distinct client/server roles',
        servers_tcpwrappers, clients_tcpwrappers, opts
    end

    context 'NFSv3 with firewall and tcpwrappers' do
      opts = {
        base_hiera: base_hiera.merge(tcpwrappers_hiera),
        export_insecure: false,
        nfs_sec: 'sys',
        nfsv3: true,
        verify_reboot: false
      }

      it_behaves_like 'a NFS share using static mounts with distinct client/server roles',
        servers_tcpwrappers, clients_tcpwrappers, opts

      it_behaves_like 'a NFS share using autofs with distinct client/server roles',
        servers_tcpwrappers, clients_tcpwrappers, opts
    end

    context 'clean up for next test' do
      (servers_tcpwrappers + clients_tcpwrappers).each do |host|
        it 'disables tcpwrappers by removing hosts.allow and hosts.deny files' do
          on(host, 'rm -f /etc/hosts.allow /etc/hosts.deny')
        end
      end
    end
  end
end
