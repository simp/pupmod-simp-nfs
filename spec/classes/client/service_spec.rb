require 'spec_helper'

# Testing private nfs::client::service class via nfs class
describe 'nfs' do
  describe 'private nfs::client::service' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) {
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge( { :haveged__rngd_enabled => false } )
        }

        context 'with default nfs and nfs::client parameters' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::client::service') }
          it { is_expected.to create_service('nfs-client.target').with( {
            :ensure     => 'running',
            :enable     => true,
            :hasrestart => false,
            :restart    => '/usr/bin/systemctl restart nfs-utils.service nfs-client.target'
          } ) }

          it { is_expected.to create_sysctl('sunrpc.tcp_slot_table_entries').with( {
            :ensure  => 'present',
            :val     => 128,
            :silent  => true
          } ) }

          it { is_expected.to create_sysctl('sunrpc.udp_slot_table_entries').with( {
            :ensure  => 'present',
            :val     => 128,
            :silent  => true
          } ) }

          it { is_expected.to create_sysctl('fs.nfs.nfs_callback_tcpport').with( {
            :ensure  => 'present',
            :val     => 876,
            :silent  => true
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
