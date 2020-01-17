require 'spec_helper'

# Testing private nfs::client class via nfs class
describe 'nfs' do
  describe 'private nfs::client' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) { os_facts}

        context 'with default nfs and nfs::client parameters' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::client::config') }
          it { is_expected.to create_class('nfs::base::config') }
          it { is_expected.to create_class('nfs::base::service') }
          it { is_expected.to create_class('nfs::client::config') }
          it { is_expected.to create_class('nfs::client::service') }
          it { is_expected.to_not create_class('krb5') }
          it { is_expected.to_not create_class('krb5::keytab') }
        end

        context 'with nfs::kerberos = true' do
          context 'with nfs::keytab_on_puppet = false' do
            let(:params) {{
              :kerberos         => true,
              :keytab_on_puppet => false
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::client') }
            it { is_expected.to create_class('krb5') }
            it { is_expected.to_not create_class('krb5::keytab') }
          end

          context 'with nfs::keytab_on_puppet = true' do
            let(:params) {{
              :kerberos         => true,
              :keytab_on_puppet => true
            }}

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
