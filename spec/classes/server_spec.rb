require 'spec_helper'

# Testing private nfs::server class via nfs class
describe 'nfs' do
  describe 'private nfs::server' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) { os_facts}

        context 'with default nfs and nfs::server parameters' do
          let(:params) {{ :is_server => true }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::server') }
          it { is_expected.to create_class('nfs::base::config') }
          it { is_expected.to create_class('nfs::base::service') }
          it { is_expected.to create_class('nfs::server::config') }
          it { is_expected.to create_class('nfs::server::service') }
          it { is_expected.to create_class('nfs::idmapd::server') }
          it { is_expected.to_not create_class('nfs::server::stunnel') }
          it { is_expected.to_not create_class('nfs::server::firewall') }
          it { is_expected.to_not create_class('krb5') }
          it { is_expected.to_not create_class('krb5::keytab') }
        end

        context 'with nfs::stunnel = true' do
          context 'with nfs::server::nfsd_vers_4_0 = false' do
            let(:params) {{
              :is_server => true,
              :stunnel   => true
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server') }
            it { is_expected.to create_class('nfs::server::stunnel') }
          end

          context 'with nfs::server::nfsd_vers4_0 = true' do
            let(:hieradata) { 'nfs_server_stunnel_and_nfsd_vers4_0' }
            it { is_expected.to_not compile.with_all_deps }
          end
        end

        context 'with nfs::firewall = true' do
          let(:params) {{
            :is_server => true,
            :firewall  => true
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::server') }
          it { is_expected.to create_class('nfs::server::firewall') }
        end

        context 'with nfs::kerberos = true' do
          context 'with nfs::keytab_on_puppet = false' do
            let(:params) {{
              :is_server        => true,
              :kerberos         => true,
              :keytab_on_puppet => false
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server') }
            it { is_expected.to create_class('krb5') }
            it { is_expected.to_not create_class('krb5::keytab') }
          end

          context 'with nfs::keytab_on_puppet = true' do
            let(:params) {{
              :is_server        => true,
              :kerberos         => true,
              :keytab_on_puppet => true
            }}

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
