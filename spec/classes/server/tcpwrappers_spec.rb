require 'spec_helper'

# Testing private nfs::server::tcpwrappers class via nfs class
describe 'nfs' do
  describe 'private nfs::server::tcpwrappers' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) {
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge( { :haveged__rngd_enabled => false } )
        }

        context 'when tcpwrappers and nfsv3 enabled' do
          let(:params) {{
            :is_server    => true,
            :nfsv3        => true,
            :tcpwrappers  => true,
            :trusted_nets => [ '1.2.3.0/24' ]
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::server::tcpwrappers') }

          if os_facts[:os][:release][:major].to_i > 7
            it { is_expected.to_not create_class('tcpwrappers') }
            it { is_expected.to_not create_tcpwrappers__allow('rpcbind') }
            it { is_expected.to_not create_tcpwrappers__allow('statd') }
            it { is_expected.to_not create_tcpwrappers__allow('mountd') }
            it { is_expected.to_not create_tcpwrappers__allow('rquotad') }
          else
            it { is_expected.to create_class('tcpwrappers') }
            it { is_expected.to create_tcpwrappers__allow('rpcbind').with_pattern(
              params[:trusted_nets]
            ) }

            it { is_expected.to create_tcpwrappers__allow('statd').with_pattern(
              params[:trusted_nets]
            ) }

            it { is_expected.to create_tcpwrappers__allow('mountd').with_pattern(
              params[:trusted_nets]
            ) }

            it { is_expected.to create_tcpwrappers__allow('rquotad').with_pattern(
              params[:trusted_nets]
            ) }
          end
        end

        context 'when tcpwrappers and nfsv3 enabled only for client' do
          let(:hieradata) { 'nfs_nfsv3_and_not_nfs_server_nfsd_vers3' }
          let(:params) {{
            :tcpwrappers  => true,
            :trusted_nets => [ '1.2.3.0/24' ]
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::server::tcpwrappers') }

          if os_facts[:os][:release][:major].to_i > 7
            it { is_expected.to_not create_class('tcpwrappers') }
            it { is_expected.to_not create_tcpwrappers__allow('rpcbind') }
            it { is_expected.to_not create_tcpwrappers__allow('statd') }
            it { is_expected.to_not create_tcpwrappers__allow('mountd') }
            it { is_expected.to_not create_tcpwrappers__allow('rquotad') }
          else
            it { is_expected.to create_class('tcpwrappers') }
            it { is_expected.to create_tcpwrappers__allow('rpcbind').with_pattern(
              params[:trusted_nets]
            ) }

            # allowed by base config
            it { is_expected.to create_tcpwrappers__allow('statd') }

            it { is_expected.to_not create_tcpwrappers__allow('mountd') }
            it { is_expected.to create_tcpwrappers__allow('rquotad').with_pattern(
              params[:trusted_nets]
            ) }
          end
        end

        context 'when tcpwrappers enabled and nfsv3 disabled' do
          let(:params) {{
            :is_server    => true,
            :nfsv3        => false,
            :tcpwrappers  => true,
            :trusted_nets => [ '1.2.3.0/24' ]
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::server::tcpwrappers') }

          if os_facts[:os][:release][:major].to_i > 7
            it { is_expected.to_not create_class('tcpwrappers') }
            it { is_expected.to_not create_tcpwrappers__allow('rpcbind') }
            it { is_expected.to_not create_tcpwrappers__allow('statd') }
            it { is_expected.to_not create_tcpwrappers__allow('mountd') }
            it { is_expected.to_not create_tcpwrappers__allow('rquotad') }
          else
            it { is_expected.to create_class('tcpwrappers') }
            it { is_expected.to create_tcpwrappers__allow('rpcbind').with_pattern(
              params[:trusted_nets]
            ) }

            it { is_expected.to_not create_tcpwrappers__allow('statd') }
            it { is_expected.to_not create_tcpwrappers__allow('mountd') }
            it { is_expected.to create_tcpwrappers__allow('rquotad').with_pattern(
              params[:trusted_nets]
            ) }
          end
        end
      end
    end
  end
end
