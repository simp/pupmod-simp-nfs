require 'spec_helper'

# Testing private nfs::base::service class via nfs class
describe 'nfs' do
  describe 'private nfs::base::service' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge({ haveged__rngd_enabled: false })
        end

        context 'NFSv3' do
          context 'with nfs::nfsv3 false' do
            let(:params) { {} } # nfs::nfsv3 default is false

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::base::service') }
            it { is_expected.to create_service('rpc-statd.service').with_ensure('stopped') }
            it {
              is_expected.to create_exec('mask_rpc-statd.service').with({
                                                                          command: '/usr/bin/systemctl mask rpc-statd.service',
              unless: '/usr/bin/systemctl status rpc-statd.service | /usr/bin/grep -qw masked',
                                                                        })
            }
          end

          context 'with nfs::nfsv3 true' do
            let(:params) { { nfsv3: true } }

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::base::service') }
            it {
              is_expected.to create_service('rpcbind.service').with({
                                                                      ensure: 'running',
              enable: true,
              hasrestart: true,
                                                                    })
            }

            it {
              is_expected.to create_service('rpc-statd.service').with({
                                                                        ensure: 'running',
              hasrestart: true,
                                                                      })
            }

            it { is_expected.to create_svckill__ignore('rpc-statd-notify') }
            it {
              is_expected.to create_exec('unmask_rpc-statd.service').with({
                                                                            command: '/usr/bin/systemctl unmask rpc-statd.service',
              onlyif: '/usr/bin/systemctl status rpc-statd.service | /usr/bin/grep -qw masked',
                                                                          })
            }
          end
        end

        context 'Secure NFS' do
          context 'with nfs::secure_nfs false' do
            let(:params) { {} } # nfs::secure_nfs default is false

            it { is_expected.to create_class('nfs::base::service') }
            it { is_expected.to create_service('rpc-gssd.service').with_ensure('stopped') }
            it {
              is_expected.to create_exec('mask_rpc-gssd.service').with({
                                                                         command: '/usr/bin/systemctl mask rpc-gssd.service',
              unless: '/usr/bin/systemctl status rpc-gssd.service | /usr/bin/grep -qw masked',
                                                                       })
            }
          end

          context 'with nfs::secure_nfs true' do
            context 'with nfs::gssd_use_gss_proxy false' do
              let(:params) do
                {
                  secure_nfs: true,
               gssd_use_gss_proxy: false,
                }
              end

              it { is_expected.to create_class('nfs::base::service') }
              it {
                is_expected.to create_service('rpc-gssd.service').with({
                                                                         ensure: 'running',
                hasrestart: true,
                                                                       })
              }

              it {
                is_expected.to create_exec('unmask_rpc-gssd.service').with({
                                                                             command: '/usr/bin/systemctl unmask rpc-gssd.service',
                onlyif: '/usr/bin/systemctl status rpc-gssd.service | /usr/bin/grep -qw masked',
                                                                           })
              }
            end

            context 'with nfs::gssd_use_gss_proxy true' do
              let(:params) do
                {
                  secure_nfs: true,
                  # nfs::gssd_use_gss_proxy default is true
                }
              end

              it { is_expected.to create_class('nfs::base::service') }
              it { is_expected.to create_service('rpc-gssd.service') }
              it { is_expected.to create_exec('unmask_rpc-gssd.service') }
              it {
                is_expected.to create_service('gssproxy.service').with({
                                                                         ensure: 'running',
                enable: true,
                hasrestart: true,
                                                                       })
              }
            end
          end
        end
      end
    end
  end
end
