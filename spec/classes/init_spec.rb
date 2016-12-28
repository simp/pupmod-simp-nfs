require 'spec_helper'

describe 'nfs' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts){ facts }

        shared_examples_for "a fact set" do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs') }
          it { is_expected.to contain_package('nfs-utils').with({
              :ensure  => 'latest'
            })
          }
          it { is_expected.to contain_package('nfs4-acl-tools').with_ensure('latest') }
          it { is_expected.to contain_class('nfs::client') }
        end

        if os =~ /(?:redhat|centos)-(\d+)/
          it_behaves_like "a fact set"
          it { is_expected.to contain_concat__fragment('nfs_init').with_content(%r(MOUNTD_PORT=20048)) }
        end

        context "as a server with default params" do
          let(:params){{
            :is_server => true
          }}
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('nfs') }
          it { is_expected.to contain_class('nfs::server') }
          it { is_expected.to_not contain_class('tcpwrappers') }
          it { is_expected.to_not contain_class('stunnel') }
          it { is_expected.to_not contain_class('krb5') }
          it { is_expected.to create_concat('/etc/sysconfig/nfs') }
          it { is_expected.to create_exec('nfs_re-export').with({
              :command     => '/usr/sbin/exportfs -ra',
              :refreshonly => true,
              :require     => 'Package[nfs-utils]'
            })
          }

          if ['RedHat','CentOS'].include?(facts[:operatingsystem]) && facts[:operatingsystemmajrelease].to_s < '7'
            it { is_expected.to contain_service('nfs').with({
                :ensure  => 'running'
              })
            }
          else
            it { is_expected.to contain_service('nfs-server').with({
                :ensure  => 'running'
              })
            }
          end
          it { is_expected.to create_file('/etc/init.d/sunrpc_tuning').with_content(/128/) }
          it { is_expected.to_not contain_class('iptables') }
          it { is_expected.to_not create_iptables__listen__tcp_stateful('nfs_client_tcp_ports') }
          it { is_expected.to_not create_iptables__listen__udp('nfs_client_udp_ports') }
          if ['RedHat','CentOS'].include?(facts[:operatingsystem])
            if facts[:operatingsystemmajrelease].to_s < '7'
              it { is_expected.to contain_service('sunrpc_tuning').with_require('[File[/etc/init.d/sunrpc_tuning]{:path=>"/etc/init.d/sunrpc_tuning"}, Service[nfs]{:name=>"nfs"}]')}
            else
              it { is_expected.to contain_service('sunrpc_tuning').with_require('[File[/etc/init.d/sunrpc_tuning]{:path=>"/etc/init.d/sunrpc_tuning"}, Service[nfs-server]{:name=>"nfs-server"}]')}
            end
          end
          it { is_expected.to contain_sysctl('sunrpc.tcp_slot_table_entries') }
          it { is_expected.to contain_sysctl('sunrpc.udp_slot_table_entries') }
          it { is_expected.to contain_concat__fragment('nfs_init_server').without_content(%r(RPCSVCGSSDARGS=)) }
        end

        context "as a server with custom args" do
          let(:hieradata) { 'rpcgssdargs' }
          let(:params) {{
            :is_server => true,
            :tcpwrappers => true,
            :stunnel => true,
            :kerberos => true,
            :firewall => true
          }}
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('nfs') }
          it { is_expected.to contain_class('nfs::server') }
          it { is_expected.to contain_concat__fragment('nfs_init_server').with_content(%r(\nRPCSVCGSSDARGS="-n -vvvvv -rrrrr -iiiiii")) }
          it { is_expected.to contain_class('tcpwrappers') }
          it { is_expected.to contain_class('stunnel') }
          it { is_expected.to contain_tcpwrappers__allow('nfs') }
          it { is_expected.to contain_tcpwrappers__allow('mountd') }
          it { is_expected.to contain_tcpwrappers__allow('statd') }
          it { is_expected.to contain_tcpwrappers__allow('rquotad') }
          it { is_expected.to contain_tcpwrappers__allow('lockd') }
          it { is_expected.to contain_tcpwrappers__allow('rpcbind') }
          it { is_expected.to contain_class('krb5') }
          it { is_expected.to contain_class('iptables') }
          it { is_expected.to create_iptables__listen__tcp_stateful('nfs_client_tcp_ports') }
          it { is_expected.to create_iptables__listen__udp('nfs_client_udp_ports') }
        end
      end
    end
  end
end
