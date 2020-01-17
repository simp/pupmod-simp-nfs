require 'spec_helper'

# Testing private nfs::client::service class via nfs class
describe 'nfs' do
  describe 'private nfs::client::service' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts){ os_facts }

        context 'with default nfs and nfs::client parameters' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::client::service') }
          it { is_expected.to create_service('nfs-client.target').with( {
            :ensure     => 'running',
            :enable     => true,
            :hasrestart => false,
            :restart    => '/usr/bin/systemctl restart nfs-utils.service nfs-client.target'
          } ) }

          it { is_expected.to_not create_service('nfs-blkmap.service') }
        end

        context 'when nfs::client::blkmap=true' do
          let(:hieradata) { 'nfs_client_blkmap' }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::client::service') }
          it { is_expected.to create_service('nfs-blkmap.service').with( {
            :ensure     => 'running',
            :enable     => true,
            :hasrestart => true
          } ) }
        end
      end
    end
  end
end
