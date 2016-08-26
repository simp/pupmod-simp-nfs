require 'spec_helper'

describe 'nfs::server' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        context "with custom args" do
          let(:pre_condition) { 'class { "nfs": is_server => true }' }
          let(:facts) { facts }
          let(:params) {{
            :rpcgssdargs    => '-vvvvvvv',
            :rpcsvcgssdargs => '-n -vvvvv -rrrrr -iiiiii',
          }}
          it { is_expected.to contain_concat_fragment('sysconfig_nfs+server').with_content(%r(\nRPCSVCGSSDARGS="-n -vvvvv -rrrrr -iiiiii")) }
        end

        context "with default params" do
          let(:pre_condition) { 'class { "nfs": is_server => true }' }
          let(:facts) { facts }
          let(:params){{ }}
          it { is_expected.to create_class('nfs::server') }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('nfs') }
          it { is_expected.to contain_class('tcpwrappers') }
          it { is_expected.to create_concat_build('nfs').with_order('*.export') }
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

          let(:params){{ }}
          it { is_expected.to contain_concat_fragment('sysconfig_nfs+server').without_content(%r(RPCSVCGSSDARGS=)) }
        end

      end
    end
  end
end
