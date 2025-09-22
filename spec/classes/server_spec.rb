require 'spec_helper'

# Testing private nfs::server class via nfs class
describe 'nfs' do
  describe 'private nfs::server' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge(haveged__rngd_enabled: false)
        end

        context 'with default nfs and nfs::server parameters' do
          let(:params) { { is_server: true } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::server') }
          it { is_expected.to create_class('nfs::base::config') }
          it { is_expected.to create_class('nfs::base::service') }
          it { is_expected.to create_class('nfs::server::config') }
          it { is_expected.to create_class('nfs::server::service') }
          it { is_expected.to create_class('nfs::idmapd::server') }
          it { is_expected.not_to create_class('nfs::server::stunnel') }
          it { is_expected.not_to create_class('nfs::server::firewall') }
          it { is_expected.not_to create_class('krb5') }
          it { is_expected.not_to create_class('krb5::keytab') }
        end

        context 'with nfs::stunnel = true' do
          context 'with nfs::server::nfsd_vers_4_0 = false' do
            let(:params) do
              {
                is_server: true,
                stunnel: true,
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server') }
            it { is_expected.to create_class('nfs::server::stunnel') }
          end

          context 'with nfs::server::nfsd_vers4_0 = true' do
            let(:hieradata) { 'nfs_server_stunnel_and_nfsd_vers4_0' }

            it { is_expected.not_to compile.with_all_deps }
          end
        end

        context 'with nfs::firewall = true' do
          let(:params) do
            {
              is_server: true,
              firewall: true,
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::server') }
          it { is_expected.to create_class('nfs::server::firewall') }
        end

        context 'with nfs::kerberos = true' do
          context 'with nfs::keytab_on_puppet = false' do
            let(:params) do
              {
                is_server: true,
                kerberos: true,
                keytab_on_puppet: false,
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server') }
            it { is_expected.to create_class('krb5') }
            it { is_expected.not_to create_class('krb5::keytab') }
          end

          context 'with nfs::keytab_on_puppet = true' do
            let(:params) do
              {
                is_server: true,
                kerberos: true,
                keytab_on_puppet: true,
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server') }
            it { is_expected.to create_class('krb5') }
            it { is_expected.to create_class('krb5::keytab') }
          end
        end
      end
    end
  end
end
