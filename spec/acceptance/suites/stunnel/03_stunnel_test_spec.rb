require 'spec_helper_acceptance'

test_name 'nfs with stunnel'

describe 'nfs stunnel' do

  before(:context) do
    hosts.each do |host|
      interfaces = fact_on(host, 'interfaces').strip.split(',')
      interfaces.delete_if do |x|
        x =~ /^lo/
      end

      interfaces.each do |iface|
        if fact_on(host, "ipaddress_#{iface}").strip.empty?
          on(host, "ifup #{iface}", :accept_all_exit_codes => true)
        end
      end
    end
  end

  servers = hosts_with_role( hosts, 'nfs_server' )
  clients = hosts_with_role( hosts, 'nfs_client' )

  let(:el6_nfs_server) { only_host_with_role(hosts, 'el6_nfs_server') }
  let(:el7_nfs_server) { only_host_with_role(hosts, 'el7_nfs_server') }

  ssh_allow = <<-EOM
    if !defined(Iptables::Listen::Tcp_stateful['i_love_testing']) {
      include '::tcpwrappers'
      include '::iptables'

      tcpwrappers::allow { 'sshd':
        pattern => 'ALL'
      }

      iptables::listen::tcp_stateful { 'i_love_testing':
        order        => 8,
        trusted_nets => ['ALL'],
        dports       => 22
      }
    }
  EOM

  let(:manifest) {
    <<-EOM
      include '::nfs'
      file { '/var/stunnel_pki':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644'
      }


      #{ssh_allow}
    EOM
  }

  let(:hieradata) {
    <<-EOM
---
# Need to test that our iptables works properly with this stuff
simp_options::firewall : true
simp_options::haveged : true
simp_options::kerberos : false
simp_options::pki : true
simp_options::stunnel : true
simp_options::tcpwrappers : true
simp_options::trusted_nets : ['ALL']

stunnel::app_pki_external_source : '/etc/pki/simp-testing/pki'

auditd : false

# There is no DNS so we need to eliminate verification
nfs::client::stunnel_verify: 0
nfs::server::stunnel::verify: 0

# These two need to be paired in our case since we expect to manage the Kerberos
# infrastructure for our tests.
nfs::kerberos : false
nfs::secure_nfs : false
nfs::is_server : #IS_SERVER#
    EOM
  }

  context 'setup' do
    hosts.each do |host|
      it 'should allow for a pki_copy' do
        # This is needed because the pki_sync type explicitly ignores cacerts.pem.
        on(host, 'cd /etc/pki/simp-testing/pki/cacerts; ln cacerts.pem tmpca.pem')
      end

      it 'should work with no errors' do
        hdata = hieradata.dup
        if servers.include?(host)
          hdata.gsub!(/#NFS_SERVER#/m, fact_on(host, 'fqdn'))
          hdata.gsub!(/#IS_SERVER#/m, 'true')
        else
          hdata.gsub!(/#NFS_SERVER#/m, servers.last.to_s)
          hdata.gsub!(/#IS_SERVER#/m, 'false')
        end

        set_hieradata_on(host, hdata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, :catch_changes => true)
      end
    end
  end

  server_manifest = <<-EOM
    #{ssh_allow}

    include '::nfs'

    file { '/srv/nfs_share':
      ensure => 'directory',
      owner  => 'root',
      group  => 'root',
      mode   => '0644'
    }

    file { '/srv/nfs_share/test_file':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => 'This is a test'
    }

    nfs::server::export { 'nfs4_root':
      clients     => ['*'],
      export_path => '/srv/nfs_share',
      sec         => ['sys'],
      # Because we're using stunnel and allowing *all* connections
      # This overrides the native 127.0.0.1 export
      insecure    => true
    }

    File['/srv/nfs_share'] -> Nfs::Server::Export['nfs4_root']
  EOM

  context "as a server" do
    servers.each do |host|
      it 'should export a directory' do
        apply_manifest_on(host, server_manifest)
      end
    end
  end

  context "as a client" do
    clients.each do |host|
      servers.each do |server|
        server_fqdn = fact_on(server,'fqdn')

        it 'should prep the stunnel connection' do
          hdata = hieradata.dup
          hdata.gsub!(/#NFS_SERVER#/m, server.to_s)
          hdata.gsub!(/#IS_SERVER#/m, 'false')

          set_hieradata_on(host, hdata)
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

        it "should mount a directory on #{server}" do
          client_manifest = <<-EOM
            #{ssh_allow}

            nfs::client::mount { '/mnt/#{server}':
              nfs_server  => '#{server_fqdn}',
              remote_path => '/srv/nfs_share',
              autofs      => false
            }
          EOM

          host.mkdir_p("/mnt/#{server}")
          apply_manifest_on(host, client_manifest)
          on(host, %(grep -q 'This is a test' /mnt/#{server}/test_file))
          on(host, %{puppet resource mount /mnt/#{server} ensure=unmounted})
        end
      end
    end
  end
end
