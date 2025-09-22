require 'spec_helper'

describe 'nfs::client::stunnel' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      before(:each) do
        # Mask 'assert_private' with mock version for testing
        Puppet::Parser::Functions.newfunction(:assert_private, type: :rvalue) { |args| }
      end

      let(:facts) do
        # to workaround service provider issues related to masking haveged
        # when tests are run on GitLab runners which are docker containers
        os_facts.merge(haveged__rngd_enabled: false)
      end

      let(:title) { '1.2.3.4:2049' }
      let(:params) do
        {
          nfs_server: '1.2.3.4',
          nfsd_accept_port: 2049,
          nfsd_connect_port: 20_490,
          stunnel_socket_options: ['l:TCP_NODELAY=1', 'r:TCP_NODELAY=1'],
          stunnel_verify: 2,
          stunnel_wantedby: ['remote-fs-pre.target'],
          firewall: true,
          tcpwrappers: true,
        }
      end

      context 'when is not the NFS server' do
        let(:pre_condition) do
          # Mask 'simplib::host_is_me' with mock version for testing
          'function simplib::host_is_me($host) { return false }'
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to create_stunnel__instance("nfs_#{title}_client_nfsd").with(
            connect: ['1.2.3.4:20490'],
            accept: '127.0.0.1:2049',
            verify: params[:stunnel_verify],
            socket_options: params[:stunnel_socket_options],
            systemd_wantedby: params[:stunnel_wantedby],
            firewall: params[:firewall],
            tcpwrappers: params[:tcpwrappers],
            tag: ['nfs'],
          )
        }
      end

      context 'when is the NFS server' do
        let(:pre_condition) do
          # Mask 'simplib::host_is_me' with mock version for testing
          'function simplib::host_is_me($host) { return true }'
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to create_stunnel__instance("nfs_#{title}_client_nfsd") }
      end
    end
  end
end
