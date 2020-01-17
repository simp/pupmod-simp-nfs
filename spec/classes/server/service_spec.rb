require 'spec_helper'

# Testing private nfs::server::service class via nfs class
describe 'nfs' do
  describe 'private nfs::server::service' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) { os_facts}

        let(:params) {{ :is_server => true, }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs::server::service') }
        it { is_expected.to create_service('nfs-server.service').with( {
          :ensure     => 'running',
          :enable     => true,
          :hasrestart => false,
          :restart    => '/usr/bin/systemctl restart nfs-utils.service nfs-server.service'
        } ) }

        it { is_expected.to create_svckill__ignore('nfs-mountd') }

        it { is_expected.to create_service('rpcbind.service').with( {
          :ensure     => 'running',
          :enable     => true,
          :hasrestart => true
        } ) }

        it { is_expected.to create_service('rpc-rquotad.service').with( {
          :ensure     => 'running',
          :enable     => true,
          :hasrestart => true
        } ) }
      end
    end
  end
end
