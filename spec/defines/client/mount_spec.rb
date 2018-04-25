require 'spec_helper'

describe 'nfs::client::mount' do
  shared_examples_for "a fact set" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('nfs::client') }
    it { is_expected.to create_nfs__client__mount__connection(title).with_nfs_server(params[:nfs_server]) }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:facts) { facts }

      let(:title) { '/home' }
      let(:clean_title) { 'home' }

      let(:params) {{
        :nfs_server  => '1.2.3.4',
        :remote_path => '/home'
      }}

      it_behaves_like "a fact set"
      it { is_expected.to contain_class('autofs') }
      it { is_expected.to contain_class('nfs::client') }

      it {
        is_expected.to contain_autofs__map__entry(title).with_location("#{params[:nfs_server]}:#{params[:remote_path]}")
      }

      context 'without autofs' do
        let(:params) {{
          :nfs_server  => '1.2.3.4',
          :remote_path => '/home',
          :autofs  => false
        }}

        it_behaves_like "a fact set"

        it {
          is_expected.to contain_mount(title).with_device("#{params[:nfs_server]}:#{params[:remote_path]}")
        }
      end

      context 'with stunnel' do
        let(:pre_condition) {
          <<-EOM
            class { 'nfs::client': stunnel => true }
          EOM
        }

        let(:params) {{
          :nfs_server  => '1.2.3.4',
          :remote_path => '/home'
        }}

        it_behaves_like "a fact set"

        it { is_expected.to contain_autofs__map__entry(title).with_location("127.0.0.1:#{params[:remote_path]}") }
        it { is_expected.to contain_exec('refresh_autofs') }
        it { is_expected.to contain_stunnel__instance("nfs4_#{params[:nfs_server]}:2049_client").that_notifies('Exec[refresh_autofs]') }

        context 'with nfsv4' do
          let(:params) {{
            :nfs_server  => '1.2.3.4',
            :remote_path => '/home',
            :nfs_version => 'nfs4'
          }}

          it_behaves_like "a fact set"
          it { is_expected.to contain_nfs__client__stunnel__v4("#{params[:nfs_server]}:2049") }
        end

        context 'without autofs' do
          let(:params) {{
            :nfs_server  => '1.2.3.4',
            :remote_path => '/home',
            :autofs  => false
          }}

          it_behaves_like "a fact set"

          it { is_expected.to contain_mount(title).with_device("127.0.0.1:#{params[:remote_path]}") }
        end
      end

      context 'with firewall enabled' do
        let(:params) {{
          :nfs_server  => '1.2.3.4',
          :remote_path => '/home',
          :nfs_version => 'nfs4'
        }}

        let(:pre_condition) {
          <<-EOM
            class { 'nfs::client': firewall => true }
          EOM
        }

        it_behaves_like "a fact set"
        it { is_expected.to contain_class('iptables') }
        it { is_expected.to contain_iptables__listen__tcp_stateful("nfs_callback_#{params[:nfs_server]}") }
      end

      context 'when nfs::client::is_server is true but the remote is not the local system' do
        let(:pre_condition) {
          <<-EOM
            class { 'nfs': is_server => true }
          EOM
        }

        let(:params){{
          :nfs_server        => '254.16.1.2',
          :autodetect_remote => false,
          :stunnel           => false,
          :remote_path       => '/home'
        }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('nfs::client') }
        it { is_expected.to contain_autofs__map__entry(title).with_location("#{params[:nfs_server]}:#{params[:remote_path]}") }
      end
    end
  end
end
