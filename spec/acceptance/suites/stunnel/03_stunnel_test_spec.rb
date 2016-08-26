require 'spec_helper_acceptance'

test_name 'nfs with stunnel'

describe 'nfs stunnel' do

  servers = hosts_with_role( hosts, 'nfs_server' )
  clients = hosts_with_role( hosts, 'nfs_client' )

  let(:el6_nfs_server) { only_host_with_role(hosts, 'el6_nfs_server') }
  let(:el7_nfs_server) { only_host_with_role(hosts, 'el7_nfs_server') }

  ssh_allow = <<-EOM
    include '::tcpwrappers'
    include '::iptables'

    tcpwrappers::allow { 'sshd':
      pattern => 'ALL'
    }

    iptables::add_tcp_stateful_listen { 'i_love_testing':
      order => '8',
      client_nets => 'ALL',
      dports => '22'
    }
  EOM

  let(:manifest) {
    <<-EOM
      include '::nfs'

      #{ssh_allow}
    EOM
  }

  let(:hieradata) {
    <<-EOM
---
# Need to test that our iptables works properly with this stuff

use_iptables : true

pki_dir : '/etc/pki/simp-testing/pki'

pki::private_key_source : "file://%{hiera('pki_dir')}/private/%{::fqdn}.pem"
pki::public_key_source : "file://%{hiera('pki_dir')}/public/%{::fqdn}.pub"
pki::cacerts_sources :
  - "file://%{hiera('pki_dir')}/cacerts"

enable_auditing : false

nfs::use_stunnel : true
nfs::server : '#NFS_SERVER#'
# Set us up for a basic server for right now (no Kerberos)

# These two need to be paired in our case since we expect to manage the Kerberos
# infrastructure for our tests.
nfs::simp_krb5 : false
nfs::secure_nfs : false
nfs::is_server : #IS_SERVER#
nfs::server::client_ips : 'ALL'
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

 context "as a server" do
    servers.each do |host|
      let(:manifest) {
        <<-EOM
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
            client      => ['*'],
            export_path => '/srv/nfs_share',
            sec         => ['sys'],
            # Because we're using stunnel and allowing *all* connections
            # This overrides the native 127.0.0.1 export
            insecure    => true
          }

          File['/srv/nfs_share'] -> Nfs::Server::Export['nfs4_root']
        EOM
      }

      it 'should export a directory' do
        apply_manifest_on(host, manifest)
      end
    end
  end

  context "as a client" do
    clients.each do |host|
      servers.each do |server|
        it 'should prep the stunnel connection' do
          hdata = hieradata.dup
          hdata.gsub!(/#NFS_SERVER#/m, server.to_s)
          hdata.gsub!(/#IS_SERVER#/m, 'false')

          set_hieradata_on(host, hdata)
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

        it "should mount a directory on #{server}" do
          host.mkdir_p("/mnt/#{server}")
          on(host, %(puppet resource mount /mnt/#{server} ensure=mounted fstype=nfs4 device='127.0.0.1:/srv/nfs_share' options='sec=sys'))
          on(host, %(grep -q 'This is a test' /mnt/#{server}/test_file))
          on(host, %{puppet resource mount /mnt/#{server} ensure=unmounted})
        end
      end
    end
  end
end
