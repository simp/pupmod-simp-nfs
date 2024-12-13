require 'spec_helper_acceptance'

test_name 'nfs krb5'

describe 'nfs krb5' do
  # This test only uses hosts that have distinct NFS server/client roles,
  # because we don't have a separate KDC in the test's Kerberos infrastructure.
  # Instead, each NFS server also acts as the KDC.
  servers = hosts_with_role(hosts, 'nfs_server')
  clients = hosts_with_role(hosts, 'nfs_client')

  base_hiera = {
    # Set us up for a NFS using Kerberos
    'simp_options::audit'                      => false,
    'simp_options::firewall'                   => true,
    'simp_options::kerberos'                   => true,
    'simp_options::stunnel'                    => false,
    'simp_options::tcpwrappers'                => true,
    'ssh::server::conf::permitrootlogin'       => true,
    'ssh::server::conf::authorizedkeysfile'    => '.ssh/authorized_keys',
    'simp_options::pki'                        => true,
    'simp_options::pki::source'                => '/etc/pki/simp-testing/pki',

    # Assuming all hosts configured to have same networks (public and private)
    'simp_options::trusted_nets'               => host_networks(hosts[0]),

    # Fake out sync source, as this is not a full SIMP server
    'krb5::keytab::keytab_source'              => 'file:///tmp/keytabs',

    # Config for KDC on NFS server (unused on NFS clients)
    'krb5::kdc::ldap'                          => false,
    'krb5::kdc::auto_keytabs::introspect'      => false,
    'krb5::kdc::auto_keytabs::hosts'           =>
      # Generate keytabs for everyone
      hosts.map { |host| [ fact_on(host, 'fqdn'), { 'ensure' => 'present' } ] }.to_h,
    'krb5::kdc::auto_keytabs::global_services' => [ 'nfs' ],

    'nfs::secure_nfs'                          => true,

    # make sure we are using iptables and not nftables because nftables
    # core dumps with rules from the nfs module
    'firewalld::firewall_backend' => 'iptables'
  }

  # We need to set up the Kerberos server prior to running NFS.
  # Otherwise, there won't be a keytab to use on the system!
  #
  # In this setup, the NFS server also acts as KDC.  But we are going to
  # copy the keytabs from the KDC onto each node manually, instead of
  # finding them in the module path (in /var/simp/environments....) of
  # the Puppet master.
  servers.each do |server|
    context "with server #{server} as NFS server and KDC" do
      let(:server_fqdn) { fact_on(server, 'fqdn') }

      context 'Kerberos infrastructure set up' do
        let(:kdc_manifest) do
          <<~EOM
            include 'krb5::kdc'
            include 'ssh'
          EOM
        end

        let(:krb5_client_manifest) do
          <<~EOM
            include 'krb5'
            include 'ssh'

            krb5::setting::realm { $facts['domain'] :
              admin_server => '#{server_fqdn}'
            }
          EOM
        end

        it "creates a KDC on NFS server #{server} with keytabs for all hosts" do
          set_hieradata_on(server, base_hiera)
          apply_manifest_on(server, kdc_manifest, catch_failures: true)
        end

        it "sets up #{server} keytab and fake keytab sync source" do
          keytab_src = %(/var/kerberos/krb5kdc/generated_keytabs/#{fact_on(server, 'fqdn')}/krb5.keytab)
          on(server, %(cp #{keytab_src} /etc))
          server.mkdir_p('/tmp/keytabs')
          on(server, "cp #{keytab_src} /tmp/keytabs/")
        end

        clients.each do |client|
          # FIXME: SIMP-7561
          it "clears the gssproxy credential cache on client #{client}" do
            on(client, 'if [ -f /var/lib/gssproxy/clients/krb5cc_0 ]; then /usr/bin/kdestroy -c /var/lib/gssproxy/clients/krb5cc_0 ; fi')
          end

          it "copies keytabs from KDC to fake keytab sync source on client #{client}" do
            keytab_src = %(/var/kerberos/krb5kdc/generated_keytabs/#{fact_on(client, 'fqdn')}/krb5.keytab)
            tmpdir = Dir.mktmpdir

            begin
              # This, combined with the krb5::keytab::keytab_source Hiera
              # parameter allow us to mock out what the Puppet server would be
              # doing.
              server.do_scp_from(keytab_src, tmpdir, {})
              client.mkdir_p('/tmp/keytabs')
              client.do_scp_to(File.join(tmpdir, File.basename(keytab_src)), '/tmp/keytabs/', {})
            ensure
              FileUtils.remove_entry_secure(tmpdir)
            end
          end

          it "sets the Kerberos realm on client #{client}" do
            set_hieradata_on(client, base_hiera)
            apply_manifest_on(client, krb5_client_manifest, catch_failures: true)
          end
        end
      end

      context 'long running test' do
        it 'ensures vagrant connectivity' do
          on(hosts, 'date')
        end
      end

      context 'Secure NFSv4 with firewall and tcpwrappers' do
        server_krb5_manifest_extras = <<~EOM
          # Keep KRB5 (kadmin & krb5kdc) ports open in firewall so clients can
          # talk to KDC
          include 'krb5::kdc'
        EOM

        client_krb5_manifest_extras = <<~EOM
          # Keep Kerberos realm configured to know location of KDC
          krb5::setting::realm { $facts['domain'] :
            admin_server => '#{fact_on(server, 'fqdn')}'
          }
        EOM

        opts = {
          base_hiera: base_hiera,
          export_insecure: false,
          server_custom: server_krb5_manifest_extras,
          client_custom: client_krb5_manifest_extras,
          nfs_sec: 'krb5p',
          nfsv3: false,
          verify_reboot: true
        }

        it_behaves_like 'a NFS share using static mounts with distinct client/server roles', [ server ], clients, opts
        it_behaves_like 'a NFS share using autofs with distinct client/server roles', [ server ], clients, opts
      end
    end
  end
end
