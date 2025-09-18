require 'spec_helper'

# Testing private nfs::server::firewall::nfsv4 class via nfs class
describe 'nfs' do
  describe 'private nfs::server::firewall::nfsv4' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge({ haveged__rngd_enabled: false })
        end

        let(:params) do
          {
            # nfs class params
            is_server: true,
          firewall: true,
          trusted_nets: [ '1.2.3.0/24' ]
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs::server::firewall::nfsv4') }
        it { is_expected.to create_class('iptables') }
        it {
          is_expected.to create_iptables__listen__tcp_stateful('nfs_client_tcp_ports').with({
                                                                                              trusted_nets: params[:trusted_nets],
          dports: [111, 2049, 875 ]
                                                                                            })
        }

        it {
          is_expected.to create_iptables__listen__udp('nfs_client_udp_ports').with({
                                                                                     trusted_nets: params[:trusted_nets],
         dports: [111, 2049, 875 ]
                                                                                   })
        }
      end
    end
  end
end
