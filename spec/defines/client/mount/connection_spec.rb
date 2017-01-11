require 'spec_helper'

describe 'nfs::client::mount::connection' do
  before(:each) do
    Puppet::Parser::Functions.newfunction('assert_private') do |f|
      f.stubs(:call).returns(true)
    end
  end

  shared_examples_for "a fact set" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('nfs::client') }
    it { is_expected.to create_nfs__client__mount__connection(title).with_nfs_server('1.2.3.4') }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:facts) { facts }

      let(:title) { '/home' }

      let(:params) {{
        :nfs_server  => '1.2.3.4',
        :nfs_version => 'nfs'
      }}

      it_behaves_like "a fact set"

      context 'with stunnel active' do
        let(:params) {{
          :nfs_server  => '1.2.3.4',
          :nfs_version => 'nfs'
        }}

        let(:pre_condition) {
          <<-EOM
            class { 'nfs::client':
              stunnel => true
            }
          EOM
        }

        it_behaves_like "a fact set"
        it { is_expected.to contain_class('nfs::client::stunnel') }
      end

      context 'with stunnel active and nfsv4' do
        let(:params) {{
          :nfs_server  => '1.2.3.4',
          :nfs_version => 'nfs4'
        }}

        let(:pre_condition) {
          <<-EOM
            class { 'nfs::client':
              stunnel => true
            }
          EOM
        }

        it_behaves_like "a fact set"
        it { is_expected.to contain_nfs__client__stunnel__v4("#{params[:nfs_server]}:2049") }
      end

      context 'with stunnel active and nfsv4' do
        let(:params) {{
          :nfs_server  => '1.2.3.4',
          :nfs_version => 'nfs4'
        }}

        let(:pre_condition) {
          <<-EOM
            class { 'nfs::client':
              stunnel => true
            }
          EOM
        }

        it_behaves_like "a fact set"
        it { is_expected.to contain_nfs__client__stunnel__v4("#{params[:nfs_server]}:2049") }
      end

      context 'with firewall enabled' do
        let(:params) {{
          :nfs_server  => '1.2.3.4',
          :nfs_version => 'nfs4'
        }}

        let(:pre_condition) {
          <<-EOM
            class { 'nfs::client':
              firewall => true
            }
          EOM
        }

        it_behaves_like "a fact set"
        it { is_expected.to contain_class('iptables') }
        it { is_expected.to contain_iptables__listen__tcp_stateful("nfs_callback_#{params[:nfs_server]}") }
      end
    end
  end
end
