require 'spec_helper'

# Testing private nfs::server::stunnel class via nfs class
describe 'nfs' do
  describe 'private nfs::server::stunnel' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) { os_facts}

        let(:params) {{
          :is_server    => true,
          :firewall     => true,
          :stunnel      => true,
          :tcpwrappers  => true,
          :trusted_nets => [ '1.2.3.0/24' ]
        }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs::server::stunnel') }

        it { is_expected.to create_stunnel__instance('nfsd').with( {
          :client           => false,
          :trusted_nets     => params[:trusted_nets],
          :connect          => [2049],
          :accept           => ['0.0.0.0:20490'],
          :verify           => 2,
          :socket_options   => ['l:TCP_NODELAY=1','r:TCP_NODELAY=1'],
          :systemd_wantedby => [ 'nfs-server.service' ],
           :firewall         => true,
           :tcpwrappers      => true,
           :tag              => ['nfs']
        } ) }
      end
    end
  end
end
