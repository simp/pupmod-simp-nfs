require 'spec_helper'

# Testing private nfs::server::stunnel class via nfs class
describe 'nfs' do
  describe 'private nfs::server::stunnel' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge(haveged__rngd_enabled: false)
        end

        let(:params) do
          {
            is_server: true,
            firewall: true,
            stunnel: true,
            tcpwrappers: true,
            trusted_nets: ['1.2.3.0/24'],
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs::server::stunnel') }

        it {
          is_expected.to create_stunnel__instance('nfsd').with(
            client: false,
            trusted_nets: params[:trusted_nets],
            connect: [2049],
            accept: ['0.0.0.0:20490'],
            verify: 2,
            socket_options: ['l:TCP_NODELAY=1', 'r:TCP_NODELAY=1'],
            systemd_wantedby: ['nfs-server.service'],
            firewall: true,
            tcpwrappers: true,
            tag: ['nfs'],
          )
        }
      end
    end
  end
end
