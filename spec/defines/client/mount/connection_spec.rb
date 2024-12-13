require 'spec_helper'

describe 'nfs::client::mount::connection' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      before(:each) do
        # Mask 'assert_private' with mock version for testing
        Puppet::Parser::Functions.newfunction(:assert_private, type: :rvalue) { |args| }
      end

      let(:pre_condition) { "include 'nfs'" }
      let(:facts) do
        # to workaround service provider issues related to masking haveged
        # when tests are run on GitLab runners which are docker containers
        os_facts.merge({ haveged__rngd_enabled: false })
      end

      let(:title) { '/mnt/apps' }

      context 'when stunnel=true and nfs_version=4' do
        let(:params) do
          {
            nfs_server: '1.2.3.4',
         nfs_version: 4,
         nfsd_port: 2049,
         firewall: true,
         stunnel: true,
         stunnel_nfsd_port: 20_490,
         stunnel_socket_options: ['l:TCP_NODELAY=1', 'r:TCP_NODELAY=1'],
         stunnel_verify: 2,
         stunnel_wantedby: [ 'remote-fs-pre.target' ],
         tcpwrappers: true
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_nfs__client__mount__connection(title) }
        it {
          is_expected.to create_nfs__client__stunnel('1.2.3.4:2049').with({
                                                                            nfs_server: params[:nfs_server],
          nfsd_accept_port: params[:nfsd_port],
          nfsd_connect_port: params[:stunnel_nfsd_port],
          stunnel_socket_options: params[:stunnel_socket_options],
          stunnel_verify: params[:stunnel_verify],
          stunnel_wantedby: params[:stunnel_wantedby],
          firewall: params[:firewall],
          tcpwrappers: params[:tcpwrappers]
                                                                          })
        }

        it { is_expected.not_to create_iptables__listen__tcp_stateful('nfs_callback_1.2.3.4') }
        it { is_expected.not_to create_iptables__listen__tcp_stateful('nfs_status_tcp_1.2.3.4') }
        it { is_expected.not_to create_iptables__listen__udp('nfs_status_udp_1.2.3.4') }
      end

      context 'when stunnel=false' do
        context 'when firewall=false' do
          let(:params) do
            {
              nfs_server: '1.2.3.4',
           nfs_version: 4,
           nfsd_port: 2049,
           firewall: false,
           stunnel: false,
           stunnel_nfsd_port: 20_490,
           stunnel_socket_options: ['l:TCP_NODELAY=1', 'r:TCP_NODELAY=1'],
           stunnel_verify: 2,
           stunnel_wantedby: [ 'remote-fs-pre.target' ],
           tcpwrappers: true
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_nfs__client__mount__connection(title) }
          it { is_expected.not_to create_class('iptables') }
          it { is_expected.not_to create_nfs__client__stunnel('1.2.3.4:2049') }
          it { is_expected.not_to create_iptables__listen__tcp_stateful('nfs_callback_1.2.3.4') }
          it { is_expected.not_to create_iptables__listen__tcp_stateful('nfs_status_tcp_1.2.3.4') }
          it { is_expected.not_to create_iptables__listen__udp('nfs_status_udp_1.2.3.4') }
        end

        context 'when firewall=true' do
          context 'when nfs_version=4' do
            let(:params) do
              {
                nfs_server: '1.2.3.4',
             nfs_version: 4,
             nfsd_port: 2049,
             firewall: true,
             stunnel: false,
             stunnel_nfsd_port: 20_490,
             stunnel_socket_options: ['l:TCP_NODELAY=1', 'r:TCP_NODELAY=1'],
             stunnel_verify: 2,
             stunnel_wantedby: [ 'remote-fs-pre.target' ],
             tcpwrappers: true
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_nfs__client__mount__connection(title) }
            it { is_expected.to create_class('iptables') }
            it { is_expected.not_to create_nfs__client__stunnel('1.2.3.4:2049') }
            it {
              is_expected.to create_iptables__listen__tcp_stateful('nfs_callback_1.2.3.4').with({
                                                                                                  trusted_nets: [ params[:nfs_server] ],
              dports: [ 876 ]
                                                                                                })
            }

            it { is_expected.not_to create_iptables__listen__tcp_stateful('nfs_status_tcp_1.2.3.4') }
            it { is_expected.not_to create_iptables__listen__udp('nfs_status_udp_1.2.3.4') }
          end

          context 'when nfs_version=3' do
            let(:params) do
              {
                nfs_server: '1.2.3.4',
             nfs_version: 3,
             nfsd_port: 2049,
             firewall: true,
             stunnel: false,
             stunnel_nfsd_port: 20_490,
             stunnel_socket_options: ['l:TCP_NODELAY=1', 'r:TCP_NODELAY=1'],
             stunnel_verify: 2,
             stunnel_wantedby: [ 'remote-fs-pre.target' ],
             tcpwrappers: true
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_nfs__client__mount__connection(title) }
            it { is_expected.not_to create_nfs__client__stunnel('1.2.3.4:2049') }
            it { is_expected.not_to create_iptables__listen__tcp_stateful('nfs_callback_1.2.3.4') }
            it {
              is_expected.to create_iptables__listen__tcp_stateful('nfs_status_tcp_1.2.3.4').with({
                                                                                                    trusted_nets: [ params[:nfs_server] ],
              dports: [ 111, 32_803, 662 ]
                                                                                                  })
            }

            it {
              is_expected.to create_iptables__listen__udp('nfs_status_udp_1.2.3.4').with({
                                                                                           trusted_nets: [ params[:nfs_server] ],
              dports: [ 111, 32_769, 662 ]
                                                                                         })
            }
          end
        end
      end
    end
  end
end
