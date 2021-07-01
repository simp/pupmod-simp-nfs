require 'spec_helper'

# Testing private nfs::client::tcpwrappers class via nfs class
describe 'nfs' do
  describe 'private nfs::client::tcpwrappers' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) {
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge( { :haveged__rngd_enabled => false } )
        }

        context 'when tcpwrappers and nfsv3 enabled' do
          let(:params) {{
            :nfsv3        => true,
            :tcpwrappers  => true,
            :trusted_nets => [ '1.2.3.0/24' ]
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::client::tcpwrappers') }

          if os_facts[:os][:release][:major].to_i > 7
            it { is_expected.to_not create_class('tcpwrappers') }
            it { is_expected.to_not create_tcpwrappers__allow('rpcbind') }
            it { is_expected.to_not create_tcpwrappers__allow('statd') }
          else
            it { is_expected.to create_class('tcpwrappers') }
            it { is_expected.to create_tcpwrappers__allow('rpcbind').with_pattern(
              params[:trusted_nets]
            ) }

            it { is_expected.to create_tcpwrappers__allow('statd') .with_pattern(
              params[:trusted_nets]
            ) }
          end
        end

        context 'when tcpwrappers enabled and nfsv3 disabled' do
          let(:params) {{
            :nfsv3        => false,
            :tcpwrappers  => true,
            :trusted_nets => [ '1.2.3.0/24' ]
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::client::tcpwrappers') }
          it { is_expected.to_not create_class('tcpwrappers') }
          it { is_expected.to_not create_tcpwrappers__allow('rpcbind') }
          it { is_expected.to_not create_tcpwrappers__allow('statd') }
        end
      end
    end
  end
end
