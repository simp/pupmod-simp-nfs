require 'spec_helper'

# Testing private nfs::server::firewall::nfsv4 class via nfs class
describe 'nfs' do
  describe 'private nfs::server::firewall::nfsv4' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) { os_facts}
        let(:params) { {
          # nfs class params
          :is_server    => true,
          :firewall     => true,
          :trusted_nets => [ '1.2.3.0/24' ]
        }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs::server::firewall::nfsv4') }
        it { is_expected.to create_class('iptables') }
        it { is_expected.to create_iptables__listen__tcp_stateful('nfs_client_tcp_ports').with( {
          :trusted_nets => params[:trusted_nets],
          :dports       => [111, 2049, 875 ]
        } ) }

        it { is_expected.to create_iptables__listen__udp('nfs_client_udp_ports').with( {
         :trusted_nets => params[:trusted_nets],
         :dports       => [111, 2049, 875 ]
        } ) }
      end
    end
  end
end
