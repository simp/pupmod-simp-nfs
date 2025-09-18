require 'spec_helper'

# Testing private nfs::client class via nfs class
describe 'nfs' do
  describe 'private nfs::client' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge(haveged__rngd_enabled: false)
        end

        context 'with default nfs and nfs::client parameters' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::base::config') }
          it { is_expected.to create_class('nfs::base::service') }
          it { is_expected.to create_class('nfs::client::config') }
          it { is_expected.to create_class('nfs::client::service') }
          it { is_expected.not_to create_class('krb5') }
          it { is_expected.not_to create_class('krb5::keytab') }
        end

        context 'with nfs::kerberos = true' do
          context 'with nfs::keytab_on_puppet = false' do
            let(:params) do
              {
                kerberos: true,
                keytab_on_puppet: false,
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::client') }
            it { is_expected.to create_class('krb5') }
            it { is_expected.not_to create_class('krb5::keytab') }
          end

          context 'with nfs::keytab_on_puppet = true' do
            let(:params) do
              {
                kerberos: true,
                keytab_on_puppet: true,
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::client') }
            it { is_expected.to create_class('krb5') }
            it { is_expected.to create_class('krb5::keytab') }
          end
        end
      end
    end
  end
end
