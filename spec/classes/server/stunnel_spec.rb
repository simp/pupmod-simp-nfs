require 'spec_helper'

describe 'nfs::server::stunnel' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:pre_condition) { 'class { "nfs": is_server => true }' }
      let(:facts) { facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('nfs::server') }
      it { is_expected.to create_stunnel__connection('nfs') }
      it { is_expected.to create_class('nfs::server::stunnel') }
    end
  end
end
