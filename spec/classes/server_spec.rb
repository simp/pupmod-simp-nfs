require 'spec_helper'

describe 'nfs::server' do
  let(:facts) {{
    :fqdn => 'spec.test',
    :grub_version => '0.97',
    :hardwaremodel => 'x86_64',
    :interfaces => 'lo',
    :ipaddress_lo => '127.0.0.1',
    :operatingsystemmajrelease => '6',
    :operatingsystem => 'RedHat',
    :operatingsystemmajrelease => '6',
    :processorcount => 4,
    :uid_min => '500'
  }}

  it { is_expected.to create_class('nfs::server') }

  context 'base' do
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
    it { is_expected.to contain_service('nfs').with({
        :ensure  => 'running',
        :require => 'Service[rpcbind]'
      })
    }
    it { is_expected.to create_file('/etc/init.d/sunrpc_tuning').with_content(/128/) }
    it { is_expected.to create_iptables__add_tcp_stateful_listen('nfs_client_tcp_ports') }
    it { is_expected.to create_iptables__add_udp_listen('nfs_client_udp_ports') }
    it { is_expected.to contain_service('sunrpc_tuning').with_require('File[/etc/init.d/sunrpc_tuning]') }
    it { is_expected.to contain_sysctl__value('sunrpc.tcp_slot_table_entries') }
    it { is_expected.to contain_sysctl__value('sunrpc.udp_slot_table_entries') }
  end
end
