require 'spec_helper'

describe 'nfs::client' do
  before(:each) do
    Puppet::Parser::Functions.newfunction('assert_private') do |f|
      f.stubs(:call).returns(true)
    end
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
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
