require 'spec_helper'

# Testing private nfs::server::service class via nfs class
describe 'nfs' do
  describe 'private nfs::server::service' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge(haveged__rngd_enabled: false)
        end

        let(:params) { { is_server: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs::server::service') }
        it {
          is_expected.to create_service('nfs-server.service').with(
            ensure: 'running',
            enable: true,
            hasrestart: false,
            restart: '/usr/bin/systemctl restart nfs-utils.service nfs-server.service',
          )
        }

        it {
          is_expected.to create_sysctl('sunrpc.tcp_slot_table_entries').with(
            ensure: 'present',
            val: 128,
            silent: true,
          )
        }

        it {
          is_expected.to create_sysctl('sunrpc.udp_slot_table_entries').with(
            ensure: 'present',
            val: 128,
            silent: true,
          )
        }

        it { is_expected.to create_svckill__ignore('nfs-mountd') }

        it {
          is_expected.to create_service('rpcbind.service').with(
            ensure: 'running',
            enable: true,
            hasrestart: true,
          )
        }

        it {
          is_expected.to create_service('rpc-rquotad.service').with(
            ensure: 'running',
            enable: true,
            hasrestart: true,
          )
        }
      end
    end
  end
end
