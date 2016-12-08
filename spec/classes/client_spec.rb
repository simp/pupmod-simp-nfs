require 'spec_helper'

describe 'nfs::client' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:facts) { facts }

      context "on #{os}" do
        it { is_expected.to create_class('nfs::client') }

        context 'base' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('nfs') }
          it { is_expected.to_not create_iptables__add_tcp_stateful_listen("nfs4_callback_port") }
          it { is_expected.to create_sysctl('fs.nfs.nfs_callback_tcpport') }
          it { is_expected.to create_file('/etc/modprobe.d/nfs.conf').with_content(/options nfs callback_tcpport=876/) }
          it { is_expected.to create_exec('modprobe_nfs').that_requires('File[/etc/modprobe.d/nfs.conf]') }
        end

        context 'with firewall = true' do
          let(:params) {{:firewall => true}}
          it { is_expected.to contain_class("iptables") }
          it { is_expected.to create_iptables__add_tcp_stateful_listen("nfs4_callback_port") }
        end
      end
    end
  end
end
