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
          it { is_expected.to contain_simpcat_fragment('sysconfig_nfs+init').with_content(%r(MOUNTD_PORT=20048)) }
          it { is_expected.to create_file('/etc/sysconfig/nfs') }
        end

        context "as a server with default params" do
          let(:params){{
            :is_server => true
          }}
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('nfs') }
          it { is_expected.to contain_class('nfs::server') }
          it { is_expected.to contain_class('tcpwrappers') }
          it { is_expected.to create_simpcat_build('nfs').with_order('*.export') }
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
          it { is_expected.to create_iptables__add_tcp_stateful_listen('nfs_client_tcp_ports') }
          it { is_expected.to create_iptables__add_udp_listen('nfs_client_udp_ports') }
          it { is_expected.to contain_service('sunrpc_tuning').with_require('File[/etc/init.d/sunrpc_tuning]') }
          it { is_expected.to contain_sysctl__value('sunrpc.tcp_slot_table_entries') }
          it { is_expected.to contain_sysctl__value('sunrpc.udp_slot_table_entries') }
          it { is_expected.to contain_simpcat_fragment('sysconfig_nfs+server').without_content(%r(RPCSVCGSSDARGS=)) }
        end

        context "as a server with custom args" do
          let(:hieradata) { 'rpcgssdargs' }
          let(:params) {{
            :is_server => true
          }}
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('nfs') }
          it { is_expected.to contain_class('nfs::server') }
          it { is_expected.to contain_simpcat_fragment('sysconfig_nfs+server').with_content(%r(\nRPCSVCGSSDARGS="-n -vvvvv -rrrrr -iiiiii")) }
        end
      end
    end
  end
end
