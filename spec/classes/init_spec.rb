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
          it { is_expected.to contain_class('nfs::client') }
          it { is_expected.to contain_class('nfs::server') }
          it { is_expected.to_not contain_class('tcpwrappers') }
          it { is_expected.to_not contain_class('krb5') }
          it { is_expected.to contain_concat__fragment('nfs_init').with_content(/SECURE_NFS=no/) }
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
          it { is_expected.to contain_service('sunrpc_tuning') }
          it { is_expected.to contain_sysctl('sunrpc.tcp_slot_table_entries') }
          it { is_expected.to contain_sysctl('sunrpc.udp_slot_table_entries') }
          it { is_expected.to contain_concat__fragment('nfs_init_server').without_content(%r(RPCSVCGSSDARGS=)) }
        end

        context "as a server with custom args" do
          let(:hieradata) { 'rpcgssdargs' }
          let(:params) {{
            :is_server   => true,
            :tcpwrappers => true,
            :stunnel     => true,
            :kerberos    => true,
            :firewall    => true
          }}
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('nfs') }
          it { is_expected.to contain_class('nfs::server') }
          it { is_expected.to contain_concat__fragment('nfs_init_server').with_content(%r(\nRPCSVCGSSDARGS="-n -vvvvv -rrrrr -iiiiii")) }
          it { is_expected.to contain_class('tcpwrappers') }
          it { is_expected.to contain_tcpwrappers__allow('nfs') }
          it { is_expected.to contain_tcpwrappers__allow('mountd') }
          it { is_expected.to contain_tcpwrappers__allow('statd') }
          it { is_expected.to contain_tcpwrappers__allow('rquotad') }
          it { is_expected.to contain_tcpwrappers__allow('lockd') }
          it { is_expected.to contain_tcpwrappers__allow('rpcbind') }
          it { is_expected.to contain_class('krb5') }
          it { is_expected.to contain_concat__fragment('nfs_init').with_content(/SECURE_NFS=no/) }
        end

        context 'with secure_nfs => true' do
          let(:hieradata) { 'server_secure' }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_concat__fragment('nfs_init').with_content(/SECURE_NFS=yes/) }

          if facts[:osfamily] == 'RedHat'
            if facts[:operatingsystemmajrelease] >= '7'
              it { is_expected.to contain_service('rpc-gssd').with(:ensure => 'running') }
              if facts[:os][:release][:full] >= '7.1.0'
                it { is_expected.to contain_service('gssproxy').with(:ensure => 'running') }
              else
                it { is_expected.to contain_service('rpc-svcgssd').with(:ensure => 'running') }
              end
            else
              it { is_expected.to contain_service('rpcgssd').with(:ensure => 'running') }
              it { is_expected.to contain_service('rpcsvcgssd').with(:ensure => 'running') }
            end
          end
        end

      end
    end
  end
end
