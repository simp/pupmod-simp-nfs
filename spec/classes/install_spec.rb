require 'spec_helper'

# Testing private nfs::install class via nfs class
describe 'nfs' do
  describe 'private nfs::install' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge({ haveged__rngd_enabled: false })
        end

        context 'default nfs and nfs::install parameters' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::install') }
          it { is_expected.to create_package('nfs-utils').with_ensure('installed') }
          it { is_expected.to create_package('nfs4-acl-tools').with_ensure('installed') }
          it { is_expected.not_to create_package('quota-rpc').with_ensure('installed') }
        end

        if os_facts[:os][:release][:major].to_i > 7
          context 'nfs::is_server=true' do
            let(:params) { { is_server: true } }

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::install') }
            it { is_expected.to create_package('nfs-utils').with_ensure('installed') }
            it { is_expected.to create_package('nfs4-acl-tools').with_ensure('installed') }
            it { is_expected.to create_package('quota-rpc').with_ensure('installed') }
          end
        end
      end
    end
  end
end
