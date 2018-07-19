require 'spec_helper'

describe 'nfs::server::stunnel' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:pre_condition) { 'class { "nfs": is_server => true }' }
      let(:facts) { facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('nfs::server') }
      it { is_expected.to create_class('nfs::server::stunnel') }
      if facts[:os][:release][:major] == '7'
        it { is_expected.to create_stunnel__instance('nfs').with_systemd_wantedby([
          'rpc-statd.service',
          'nfs-mountd.service',
          'nfs-rquotad.service',
          'nfs-server.service',
          'rpcbind.socket',
          'nfs-idmapd.service',
          'rpc-gssd.service',
          'gssproxy.service',
        ] ) }
      end
    end
  end
end
