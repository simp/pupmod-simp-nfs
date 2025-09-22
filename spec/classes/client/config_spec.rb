require 'spec_helper'

# Testing private nfs::client::config class via nfs class
describe 'nfs' do
  describe 'private nfs::client::config' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge(haveged__rngd_enabled: false)
        end

        context 'with default nfs and nfs::client parameters' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::client::config') }
          it {
            is_expected.to create_exec('modprobe_nfsv4').with(
              command: '/sbin/modprobe nfsv4',
              unless: '/sbin/lsmod | /usr/bin/grep -qw nfsv4',
            )
          }

          it {
            is_expected.to create_file('/etc/modprobe.d/nfs.conf').with(
              owner: 'root',
              group: 'root',
              mode: '0640',
              content: <<~EOM,
                # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
                # at the next puppet run.
                #
                options nfs callback_tcpport=876
              EOM
            )
          }

          it {
            is_expected.to create_file('/etc/exports').with(
              owner: 'root',
              group: 'root',
              mode: '0644',
              content: "\n",
            )
          }

          it { is_expected.not_to create_class('nfs::client::tcpwrappers') }
          it { is_expected.not_to create_class('nfs::idmapd::client') }
        end

        context 'when nfs::is_server=true' do
          let(:params) { { is_server: true } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::client::config') }
          it { is_expected.not_to create_file('/etc/exports') }
        end

        context 'when nfs::tcpwrappers=true' do
          let(:params) { { tcpwrappers: true } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::client::config') }
          it { is_expected.to create_class('nfs::client::tcpwrappers') }
        end

        context 'when nfs::idmapd=true' do
          let(:params) { { idmapd: true } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::client::config') }
          it { is_expected.to create_class('nfs::idmapd::client') }
        end
      end
    end
  end
end
