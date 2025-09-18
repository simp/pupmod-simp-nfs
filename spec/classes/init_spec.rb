require 'spec_helper'

describe 'nfs' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) do
        # to workaround service provider issues related to masking haveged
        # when tests are run on GitLab runners which are docker containers
        os_facts.merge(haveged__rngd_enabled: false)
      end

      shared_examples_for 'a NFS base installer' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs') }
        it { is_expected.to create_class('nfs::install') }
      end

      context 'with default parameters' do
        it_behaves_like 'a NFS base installer'
        it { is_expected.not_to create_class('nfs::selinux_hotfix') }
        it { is_expected.to create_class('nfs::lvm2') }
        it { is_expected.to create_class('nfs::client') }
        it { is_expected.not_to create_class('nfs::server') }
      end

      context 'with kerberos=true' do
        let(:params) { { kerberos: true } }

        it_behaves_like 'a NFS base installer'
        if os_facts[:os][:release][:major].to_i < 8
          it { is_expected.to create_class('nfs::selinux_hotfix') }
        else
          it { is_expected.not_to create_class('nfs::selinux_hotfix') }
        end
      end

      context 'ensure_latest_lvm=false' do
        let(:params) { { ensure_latest_lvm2: false } }

        it_behaves_like 'a NFS base installer'
        it { is_expected.not_to create_class('nfs::lvm2') }
      end

      context 'is_client=false' do
        let(:params) { { is_client: false } }

        it_behaves_like 'a NFS base installer'
        it { is_expected.not_to create_class('nfs::client') }
      end

      context 'is_server=true' do
        let(:params) { { is_server: true } }

        it_behaves_like 'a NFS base installer'
        it { is_expected.to create_class('nfs::server') }
      end
    end
  end
end
