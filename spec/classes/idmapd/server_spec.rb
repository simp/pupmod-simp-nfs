require 'spec_helper'

# Testing private nfs::idmapd::server class via nfs class
describe 'nfs' do
  describe 'private nfs::idmapd::server' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) {
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge( { :haveged__rngd_enabled => false } )
        }

        context 'with nfs::idmapd=true' do
          let(:params) {{
            :is_server => true,
            :idmapd    => true
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::idmapd::server') }
          it { is_expected.to create_class('nfs::idmapd::config') }
          it { is_expected.to create_service('nfs-idmapd.service').with( {
              :ensure     => 'running',
              :enable     => true,
              :hasrestart => true
            } )
          }

          it { is_expected.to create_exec('unmask_nfs-idmapd.service').with( {
              :command => '/usr/bin/systemctl unmask nfs-idmapd.service',
              :onlyif  => '/usr/bin/systemctl status nfs-idmapd.service | /usr/bin/grep -qw masked'
            } )
          }
        end

        context 'with nfs::idmapd=false' do
          let(:params) {{
            :is_server => true,
            :idmapd    => false
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::idmapd::server') }
          it { is_expected.to_not create_class('nfs::idmapd::config') }
          it { is_expected.to create_service('nfs-idmapd.service').with( {
              :ensure => 'stopped'
            } )
          }

          it { is_expected.to create_exec('mask_nfs-idmapd.service').with( {
              :command => '/usr/bin/systemctl mask nfs-idmapd.service',
              :unless  => '/usr/bin/systemctl status nfs-idmapd.service | /usr/bin/grep -qw masked'
            } )
          }
        end
      end
    end
  end
end
