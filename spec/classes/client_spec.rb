require 'spec_helper'

describe 'nfs::client' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      context "on #{os}" do
        it { is_expected.to create_class('nfs::client') }

        context 'base' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('nfs') }
          it { is_expected.to create_sysctl('fs.nfs.nfs_callback_tcpport') }
          it { is_expected.to create_file('/etc/modprobe.d/nfs.conf').with_content(/options nfs callback_tcpport=876/) }
          it { is_expected.to create_exec('modprobe_nfs').that_requires('File[/etc/modprobe.d/nfs.conf]') }
        end
      end
    end
  end
end
