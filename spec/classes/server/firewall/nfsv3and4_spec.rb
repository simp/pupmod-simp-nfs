require 'spec_helper'

# Testing private nfs::server::firewall::nfsv3and4 class via nfs class
describe 'nfs' do
  describe 'private nfs::server::firewall::nfs3andv4' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) {
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge( { :haveged__rngd_enabled => false } )
        }

        let(:params) { {
          # nfs class params
          :is_server    => true,
          :nfsv3        => true,
          :firewall     => true,
          :trusted_nets => [ '1.2.3.0/24' ]
        }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs::server::firewall::nfsv3and4') }
        it { is_expected.to create_class('iptables') }
        it { is_expected.to create_iptables__listen__tcp_stateful('nfs_client_tcp_ports').with( {
          :trusted_nets => params[:trusted_nets],
          :dports       => [111, 2049, 875, 20048, 662, 32803]
        } ) }

        it { is_expected.to create_iptables__listen__udp('nfs_client_udp_ports').with( {
          :trusted_nets => params[:trusted_nets],
          :dports       => [111, 2049, 875, 20048, 662, 32769]
        } ) }
      end
    end
  end
end
