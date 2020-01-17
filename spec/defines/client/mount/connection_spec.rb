require 'spec_helper'

describe 'nfs::client::mount::connection' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      before(:each) do
        # Mask 'assert_private' with mock version for testing
        Puppet::Parser::Functions.newfunction(:assert_private, :type => :rvalue) { |args| }
      end

      let(:pre_condition) { "include 'nfs'" }
      let(:facts) { os_facts }
      let(:title) { '/mnt/apps' }

      context 'when stunnel=true and nfs_version=4' do
        let(:params) {{
          :nfs_server             => '1.2.3.4',
          :nfs_version            => 4,
          :nfsd_port              => 2049,
          :firewall               => true,
          :stunnel                => true,
          :stunnel_nfsd_port      => 20490,
          :stunnel_socket_options => ['l:TCP_NODELAY=1','r:TCP_NODELAY=1'],
          :stunnel_verify         => 2,
          :stunnel_wantedby       => [ 'remote-fs-pre.target' ],
          :tcpwrappers            => true
        }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_nfs__client__mount__connection(title) }
        it { is_expected.to create_nfs__client__stunnel('1.2.3.4:2049').with( {
          :nfs_server             => params[:nfs_server],
          :nfsd_accept_port       => params[:nfsd_port],
          :nfsd_connect_port      => params[:stunnel_nfsd_port],
          :stunnel_socket_options => params[:stunnel_socket_options],
          :stunnel_verify         => params[:stunnel_verify],
          :stunnel_wantedby       => params[:stunnel_wantedby],
          :firewall               => params[:firewall],
          :tcpwrappers            => params[:tcpwrappers]
        } ) }

        it { is_expected.to_not create_iptables__listen__tcp_stateful('nfs_callback_1_2_3_4') }
        it { is_expected.to_not create_iptables__listen__tcp_stateful('nfs_status_tcp_1_2_3_4') }
        it { is_expected.to_not create_iptables__listen__udp('nfs_status_udp_1_2_3_4') }
      end

      context 'when stunnel=false' do
        context 'when firewall=false' do
          let(:params) {{
            :nfs_server             => '1.2.3.4',
            :nfs_version            => 4,
            :nfsd_port              => 2049,
            :firewall               => false,
            :stunnel                => false,
            :stunnel_nfsd_port      => 20490,
            :stunnel_socket_options => ['l:TCP_NODELAY=1','r:TCP_NODELAY=1'],
            :stunnel_verify         => 2,
            :stunnel_wantedby       => [ 'remote-fs-pre.target' ],
            :tcpwrappers            => true
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_nfs__client__mount__connection(title) }
          it { is_expected.to_not create_class('iptables') }
          it { is_expected.to_not create_nfs__client__stunnel('1.2.3.4:2049') }
          it { is_expected.to_not create_iptables__listen__tcp_stateful('nfs_callback_1_2_3_4') }
          it { is_expected.to_not create_iptables__listen__tcp_stateful('nfs_status_tcp_1_2_3_4') }
          it { is_expected.to_not create_iptables__listen__udp('nfs_status_udp_1_2_3_4') }
        end

        context 'when firewall=true' do
          context 'when nfs_version=4' do
            let(:params) {{
              :nfs_server             => '1.2.3.4',
              :nfs_version            => 4,
              :nfsd_port              => 2049,
              :firewall               => true,
              :stunnel                => false,
              :stunnel_nfsd_port      => 20490,
              :stunnel_socket_options => ['l:TCP_NODELAY=1','r:TCP_NODELAY=1'],
              :stunnel_verify         => 2,
              :stunnel_wantedby       => [ 'remote-fs-pre.target' ],
              :tcpwrappers            => true
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_nfs__client__mount__connection(title) }
            it { is_expected.to create_class('iptables') }
            it { is_expected.to_not create_nfs__client__stunnel('1.2.3.4:2049') }
            it { is_expected.to create_iptables__listen__tcp_stateful('nfs_callback_1_2_3_4').with( {
              :trusted_nets => [ params[:nfs_server] ],
              :dports       => [ 876 ]
            } ) }

            it { is_expected.to_not create_iptables__listen__tcp_stateful('nfs_status_tcp_1_2_3_4') }
            it { is_expected.to_not create_iptables__listen__udp('nfs_status_udp_1_2_3_4') }
          end

          context 'when nfs_version=3' do
            let(:params) {{
              :nfs_server             => '1.2.3.4',
              :nfs_version            => 3,
              :nfsd_port              => 2049,
              :firewall               => true,
              :stunnel                => false,
              :stunnel_nfsd_port      => 20490,
              :stunnel_socket_options => ['l:TCP_NODELAY=1','r:TCP_NODELAY=1'],
              :stunnel_verify         => 2,
              :stunnel_wantedby       => [ 'remote-fs-pre.target' ],
              :tcpwrappers            => true
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_nfs__client__mount__connection(title) }
            it { is_expected.to_not create_nfs__client__stunnel('1.2.3.4:2049') }
            it { is_expected.to_not create_iptables__listen__tcp_stateful('nfs_callback_1_2_3_4') }
            it { is_expected.to create_iptables__listen__tcp_stateful('nfs_status_tcp_1_2_3_4').with({
              :trusted_nets => [ params[:nfs_server] ],
              :dports       => [ 111, 32803, 662 ]
            } ) }

            it { is_expected.to create_iptables__listen__udp('nfs_status_udp_1_2_3_4').with({
              :trusted_nets => [ params[:nfs_server] ],
              :dports       => [ 111, 32769, 662 ]
            } ) }
          end
        end
      end
    end
  end
end
