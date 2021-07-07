require 'spec_helper'

# Testing private nfs::server::firewall class via nfs class
describe 'nfs' do
  describe 'private nfs::server::firewall' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) {
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge( { :haveged__rngd_enabled => false } )
        }

        context 'when stunnel enabled' do
          context 'when nfsv3 enabled' do
            let(:params) { {
              # nfs class params
              :is_server => true,
              :nfsv3     => true,
              :firewall  => true,
              :stunnel   => true
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server::firewall') }
            it { is_expected.to create_class('nfs::server::firewall::nfsv3and4') }
            it { is_expected.to_not create_class('nfs::server::firewall::nfsv4') }
          end

          context 'when nfsv3 only enabled for the NFS client' do
            let(:hieradata) { 'nfs_nfsv3_and_not_nfs_server_nfsd_vers3' }
            let(:params) { {
              # nfs class params
              :firewall  => true,
              :stunnel   => true
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server::firewall') }
            it { is_expected.to_not create_class('nfs::server::firewall::nfsv3and4') }
            it { is_expected.to_not create_class('nfs::server::firewall::nfsv4') }
          end

          context 'when nfsv3 disabled' do
            let(:params) { {
              # nfs class params
              :is_server => true,
              :nfsv3     => false,
              :firewall  => true,
              :stunnel   => true
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server::firewall') }
            it { is_expected.to_not create_class('nfs::server::firewall::nfsv3and4') }
            it { is_expected.to_not create_class('nfs::server::firewall::nfsv4') }
          end
        end

        context 'when stunnel disabled' do
          context 'when nfsv3 enabled' do
            let(:params) { {
              # nfs class params
              :is_server => true,
              :nfsv3     => true,
              :firewall  => true,
              :stunnel   => false
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server::firewall::nfsv3and4') }
            it { is_expected.to_not create_class('nfs::server::firewall::nfsv4') }
          end

          context 'when nfsv3 only enabled for the NFS client' do
            let(:hieradata) { 'nfs_nfsv3_and_not_nfs_server_nfsd_vers3' }
            let(:params) { {
              # nfs class params
              :firewall  => true,
              :stunnel   => false
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to_not create_class('nfs::server::firewall::nfsv3and4') }
            it { is_expected.to create_class('nfs::server::firewall::nfsv4') }
          end

          context 'when nfsv3 disabled' do
            let(:params) { {
              # nfs class params
              :is_server => true,
              :nfsv3     => false,
              :firewall  => true,
              :stunnel   => false
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to_not create_class('nfs::server::firewall::nfsv3and4') }
            it { is_expected.to create_class('nfs::server::firewall::nfsv4') }
          end
        end
      end
    end
  end
end
