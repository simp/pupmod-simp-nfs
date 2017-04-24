require 'spec_helper'

# most of server class is tested in init_spec.rb.  Here we are focusing on the
# content of the concat fragment
describe 'nfs::server' do
  before(:each) do
    Puppet::Parser::Functions.newfunction('assert_private') do |f|
      f.stubs(:call).returns(true)
    end
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:facts) { facts }

      context "on #{os}" do

        context 'with default parameters' do
          let(:hieradata) { 'server' }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_concat__fragment('nfs_init_server').with_content(<<EOM
RQUOTAD=no
RQUOTAD_PORT=875
LOCKD_TCPPORT=32803
LOCKD_UDPPORT=32769
EOM
          ) }
        end

        context 'with optional parameters set and nfsv3 true' do
          let(:hieradata) { 'server' }
          let(:params) {{
            :nfsv3            => true,
            :rpcrquotadopts   => 'some rpcrquotad opts',
            :lockd_arg        => 'some lockd args',
            :nfsd_module      => 'force noload',
            :rpcmountdopts    => 'some rpcmountd opts',
            :statdarg         => 'some statd args',
            :statd_ha_callout => '/the/statd/ha/callout/program',
            :rpcidmapdargs    => 'some rpcidmapd args',
            :rpcgssdargs      => 'some rpcgssd args',
            :rpcsvcgssdargs   => 'some rpcsvcgssd args'
          }}
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_concat__fragment('nfs_init_server').with_content(<<EOM
RQUOTAD="/usr/sbin/rpc.rquotad"
RQUOTAD_PORT=875
RPCRQUOTADOPTS="some rpcrquotad opts"
LOCKD_ARG="some lockd args"
LOCKD_TCPPORT=32803
LOCKD_UDPPORT=32769
NFSD_MODULE="noload"
RPCMOUNTDOPTS="some rpcmountd opts"
STATDARG="some statd args"
STATD_HA_CALLOUT="/the/statd/ha/callout/program"
RPCIDMAPDARGS="some rpcidmapd args"
RPCGSSDARGS="some rpcgssd args"
RPCSVCGSSDARGS="some rpcsvcgssd args"
EOM
          ) }
        end

#	      context 'with secure_nfs => true' do
#          let(:hieradata) { 'server_secure' }
#          it { is_expected.to compile.with_all_deps }
#
#          if facts[:osfamily] == 'RedHat'
#            if facts[:operatingsystemmajrelease] >= '7'
#      #if (versioncmp($facts['os']['release']['full'], '7.1') < 0) {
#      #  $rpcsvcgssd  = 'rpc-svcgssd'
#      #}
#              it { is_expected.to contain_concat__fragment("nfs_init_server").with_content(/SECURE_NFS=yes/) }
#              it { is_expected.to contain_service('gssproxy').with(:ensure => 'running') }
#            else
#              it { is_expected.to contain_service('rpcsvcgssd').with(:ensure => 'running') }
#            end
#          end
#      	end
      end
    end
  end
end
