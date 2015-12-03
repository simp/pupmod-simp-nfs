require 'spec_helper'

describe 'nfs::client' do
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

  it { is_expected.to create_class('nfs::client') }

  context 'base' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('nfs') }
    it { is_expected.to create_iptables__add_tcp_stateful_listen('nfs4_callback_port_testnode.example.domain') }
    it { is_expected.to create_sysctl__value('fs.nfs.nfs_callback_tcpport') }
    it { is_expected.to create_file('/etc/modprobe.d/nfs.conf').with_content(/options nfs callback_tcpport=876/) }
    it { is_expected.to create_exec('modprobe_nfs').that_requires('File[/etc/modprobe.d/nfs.conf]') }
  end
end
