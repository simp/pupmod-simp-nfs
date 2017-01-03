require 'spec_helper'

describe 'nfs::client::stunnel' do
  before(:each) do
    Puppet::Parser::Functions.newfunction('assert_private') do |f|
      f.stubs(:call).returns(true)
    end
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:facts) { facts }

      let(:params) {{
        :nfs_server => '1.2.3.4'
      }}

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('nfs::client::stunnel') }
      it { is_expected.to create_stunnel__connection('nfs_client') }
    end
  end
end
