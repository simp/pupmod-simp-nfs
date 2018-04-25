require 'spec_helper_acceptance'

test_name 'nfs krb5'

describe 'nfs krb5' do

  servers = hosts_with_role( hosts, 'nfs_server' )
  clients = hosts_with_role( hosts, 'nfs_client' )

  def trusted_nets(target_hosts = hosts)
    host_ipaddresses = []

    target_hosts.each do |host|
      host_ifaces = fact_on(host, 'interfaces').split(',')

      host_ifaces.each do |iface|
        unless iface == 'lo'
          host_ipaddresses << fact_on(host, "ipaddress_#{iface}")
        end
      end

      etc_hosts = on(host, 'puppet resource host').stdout.strip
      etc_hosts = etc_hosts.lines.map!{|x| x.strip =~ /ip\s+=>\s+(?:'|")(.*)(?:'|")/; x = $1}
      etc_hosts.delete_if{|x| x.nil? || x.empty? || x == '127.0.0.1'}

      host_ipaddresses = (etc_hosts + host_ipaddresses).flatten.uniq.compact
      host_ipaddresses.delete_if{|x| x =~ /^\s*$/}
    end

    host_ipaddresses
  end

  let(:puppet_confdir) {
    on(host, %(puppet config print confdir)).stdout.strip
  }

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

  manifest = <<-EOM
    include '::nfs'
    include '::krb5'

    #{ssh_allow}
  EOM

  let(:hieradata) {
    <<-EOM
---
simp_options::trusted_nets :
#{trusted_nets.map{|ip| ip = %(  - '#{ip}')}.join("\n")}

simp_options::firewall : true
simp_options::stunnel : false
simp_options::tcpwrappers : true
simp_options::kerberos : true

pki_dir : '/etc/pki/simp-testing/pki'

pki::private_key_source : "file://%{hiera('pki_dir')}/private/%{::fqdn}.pem"
pki::public_key_source : "file://%{hiera('pki_dir')}/public/%{::fqdn}.pub"
pki::cacerts_sources :
  - "file://%{hiera('pki_dir')}/cacerts"

auditd : false

krb5::kdc::ldap : false
krb5::keytab::keytab_source : 'file:///tmp/keytabs'

# Generate keytabs for everyone
krb5::kdc::auto_keytabs::hosts :
#{hosts.map{|host| host = %(  '#{fact_on(host,'fqdn')}' :\n    'ensure' : 'present')}.join("\n")}

krb5::kdc::auto_keytabs::global_services :
  - 'nfs'

# These two need to be paired in our case since we expect to manage the Kerberos
# infrastructure for our tests.
nfs::secure_nfs : true
nfs::is_server : #IS_SERVER#
    EOM
  }

  server_manifest = <<-EOM
    # Keep the SSH ports open
    #{ssh_allow}

    # Keep the KRB5 ports open
    include '::krb5::kdc'
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
      sec         => ['krb5p']
    }

    File['/srv/nfs_share'] -> Nfs::Server::Export['nfs4_root']
  EOM

  context "as a server" do
    servers.each do |host|
      it 'should pre-build a Kerberos infrastructure' do
        # We need to set up the Kerberos server prior to running NFS.
        # Otherwise, there won't be a keytab to use on the system!
        #
        # This is a bit roundabout since, in a real system, you would
        # orchestrate this via a profile somewhere.
        keytab_src = %(/var/kerberos/krb5kdc/generated_keytabs/#{fact_on(host,'fqdn')}/krb5.keytab)

        krb5_manifest = "include '::krb5::kdc'\n#{ssh_allow}"

        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, krb5_manifest)

        on(host, %(cp #{keytab_src} /etc))
      end

      it 'should prep the fake keytab sync source' do
        keytab_src = %(/var/kerberos/krb5kdc/generated_keytabs/#{fact_on(host,'fqdn')}/krb5.keytab)

        host.mkdir_p('/tmp/keytabs')
        on(host, "cp #{keytab_src} /tmp/keytabs/")
      end

      it 'should work with no errors' do
        hdata = hieradata.dup
        hdata.gsub!(/#NFS_SERVER#/m, fact_on(host, 'fqdn'))
        hdata.gsub!(/#IS_SERVER#/m, 'true')

        set_hieradata_on(host, hdata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, {:catch_changes => true})
      end

      it 'should export a directory' do
        apply_manifest_on(host, server_manifest, :catch_failures => true)
      end
    end
  end

  clients.each do |host|
    servers.each do |server|
      context "as a client" do
        let(:server_fqdn) { fact_on(server, 'fqdn') }

        let(:krb5_client_manifest) { <<-EOM
          krb5::setting::realm { $::domain :
            admin_server => '#{server_fqdn}'
          }
          EOM
        }

        # We aren't using DNS here, so we need to make sure that the kerberos
        # client is pointing to the correct location.
        it "should set up the KRB5 client for the appropriate realm" do
          hdata = hieradata.dup
          hdata.gsub!(/#NFS_SERVER#/m, server_fqdn)
          hdata.gsub!(/#IS_SERVER#/m, 'false')

          _manifest = manifest.dup + krb5_client_manifest

          keytab_src = %(/var/kerberos/krb5kdc/generated_keytabs/#{fact_on(host,'fqdn')}/krb5.keytab)

          # Pulling this directly over so that we don't have to worry about
          # Puppet server-fu in the middle of all of this. That should be
          # tested separately.
          tmpdir = Dir.mktmpdir

          begin
            # This, combined with the krb5::keytab::keytab_source Hiera
            # parameter allow us to mock out what the Puppet server would be
            # doing.
            server.do_scp_from(keytab_src, tmpdir, {})
            host.mkdir_p('/tmp/keytabs')
            host.do_scp_to(File.join(tmpdir, File.basename(keytab_src)), "/tmp/keytabs/", {})
          ensure
            FileUtils.remove_entry_secure(tmpdir)
          end

          set_hieradata_on(host, hdata)
          apply_manifest_on(host, _manifest, :catch_failures => true)
        end

        it "should mount a directory on the #{server} server" do
          client_manifest = <<-EOM
            #{ssh_allow}

            nfs::client::mount { '/mnt/#{server}':
              nfs_server  => '#{server_fqdn}',
              remote_path => '/srv/nfs_share',
              sec         => 'krb5p',
              autofs      => false
            }
          EOM

          if servers.include?(host)
            client_manifest = client_manifest + "\n" + server_manifest
          else
            client_manifest = client_manifest + "\n" + krb5_client_manifest
          end

          host.mkdir_p("/mnt/#{server}")
          apply_manifest_on(host, client_manifest, :catch_failures => true)
          on(host, %(grep -q 'This is a test' /mnt/#{server}/test_file))
          on(host, %{puppet resource mount /mnt/#{server} ensure=unmounted})
        end

        it "should mount a directory on the #{server} server with autofs" do
          autofs_client_manifest = <<-EOM
            #{ssh_allow}

            nfs::client::mount { '/mnt/#{server}':
              nfs_server  => '#{server_fqdn}',
              remote_path => '/srv/nfs_share'
            }
          EOM

          if servers.include?(host)
            autofs_client_manifest = autofs_client_manifest + "\n" + server_manifest
          else
            autofs_client_manifest = autofs_client_manifest + "\n" + krb5_client_manifest
          end

          # apply_manifest_on(host, autofs_client_manifest)
          apply_manifest_on(host, autofs_client_manifest, catch_failures: true)
          apply_manifest_on(host, autofs_client_manifest, catch_changes: true)

          on(host, %{puppet resource service autofs ensure=stopped})
        end
      end
    end
  end
end
