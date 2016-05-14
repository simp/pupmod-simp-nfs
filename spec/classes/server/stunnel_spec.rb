require 'spec_helper'

describe 'nfs::server::stunnel' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:pre_condition) { 'include "nfs::server"' }
      let(:facts) { facts }

      it { is_expected.to create_class('nfs::server::stunnel') }

      context 'base' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('nfs::server') }
        it { is_expected.to create_stunnel__add('nfs') }
      end
    end
  end
end
