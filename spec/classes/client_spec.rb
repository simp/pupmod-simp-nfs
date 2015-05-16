require 'spec_helper'

describe 'nfs::client' do
  let(:facts) {{
    :fqdn => 'spec.test',
    :grub_version => '0.97',
    :hardwaremodel => 'x86_64',
    :interfaces => 'lo',
    :ipaddress_lo => '127.0.0.1',
    :lsbmajdistrelease => '6',
    :operatingsystem => 'RedHat',
    :operatingsystemmajrelease => '6',
    :processorcount => 4,
    :uid_min => '500'
  }}

  it { should create_class('nfs::client') }

  context 'base' do
    it { should compile.with_all_deps }
    it { should contain_class('nfs') }
    it { should create_iptables__add_tcp_stateful_listen('nfs4_callback_port_testnode.example.domain') }
    it { should create_sysctl__value('fs.nfs.nfs_callback_tcpport') }
    it { should create_file('/etc/modprobe.d/nfs.conf').with_content(/options nfs callback_tcpport=876/) }
  end
end
