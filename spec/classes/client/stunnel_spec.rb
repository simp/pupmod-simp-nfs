require 'spec_helper'

describe 'nfs::client::stunnel' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:facts) { facts }

      it { is_expected.to create_class('nfs::client::stunnel') }

      context 'base' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_stunnel__add('nfs_client') }
      end
    end
  end
end
