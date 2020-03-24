require 'spec_helper'

# Testing private nfs::base::config class via nfs class
describe 'nfs' do
  describe 'private nfs::base::config' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) { os_facts }

        context 'with default nfs parameters' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::base::config') }
          it { is_expected.to create_concat('/etc/nfs.conf').with( {
            :owner => 'root',
            :group => 'root',
            :mode  => '0644'
          } ) }

          it { is_expected.to_not create_concat__fragment('nfs_conf_general') }
          it { is_expected.to_not create_concat__fragment('nfs_conf_gssd') }
          it { is_expected.to_not create_concat__fragment('nfs_conf_lockd') }
          it { is_expected.to_not create_concat__fragment('nfs_conf_sm_notify') }
          it { is_expected.to_not create_concat__fragment('nfs_conf_statd') }

          if os_facts[:os][:release][:major].to_i < 8
            it { is_expected.to create_concat('/etc/sysconfig/nfs').with( {
              :owner => 'root',
              :group => 'root',
              :mode  => '0644'
            } ) }

            it { is_expected.to_not create_concat__fragment('nfs_gss_use_proxy') }
            it { is_expected.to_not create_concat__fragment('nfs_GSSDARGS') }
            it { is_expected.to_not create_concat__fragment('nfs_SMNOTIFYARGS') }
            it { is_expected.to_not create_concat__fragment('nfs_STATDARG') }
          else
            it { is_expected.to create_file('/etc/sysconfig/nfs').with_ensure('absent') }
          end

          it { is_expected.to_not create_systemd__dropin_file('simp_unit.conf') }
          it { is_expected.to create_file('/etc/modprobe.d/sunrpc.conf').with( {
            :owner   => 'root',
            :group   => 'root',
            :mode    => '0640',
            :content => <<~EOM
              # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
              # at the next puppet run.
              #
              options sunrpc tcp_slot_table_entries=128 udp_slot_table_entries=128
            EOM
          } ) }

          it { is_expected.to_not create_class('nfs::idmapd::config') }
          it { is_expected.to_not create_file('/etc/modprobe.d/lockd.conf') }
        end

        context "when nfs::custom_nfs_conf_opts has 'general' key" do
          let(:params) {{
            :custom_nfs_conf_opts => {
              'general' => {
                'pipefs-directory' => '/some/dir'
              }
            }
          }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::base::config') }
          it { is_expected.to create_concat__fragment('nfs_conf_general').with( {
            :target  => '/etc/nfs.conf',
            :content => <<~EOM

              [general]
                pipefs-directory = /some/dir
              EOM
          } ) }
        end

        context 'when nfs::secure_nfs=true' do
          context 'when nfs::gssd_use_gss_proxy=false' do
            let(:params) {{
              :secure_nfs         => true,
              :gssd_use_gss_proxy => false
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::base::config') }
            it { is_expected.to create_concat__fragment('nfs_conf_gssd').with( {
              :target  => '/etc/nfs.conf',
              :content => <<~EOM

                [gssd]
                  avoid-dns = true
                  limit-to-legacy-enctypes = false
                  use-gss-proxy = false
                EOM
            } ) }

            if os_facts[:os][:release][:major].to_i < 8
              it { is_expected.to_not create_concat__fragment('nfs_gss_use_proxy') }
              it { is_expected.to_not create_concat__fragment('nfs_GSSDARGS') }
            end

            it { is_expected.to_not create_systemd__dropin_file('simp_unit.conf') }
          end

          context 'when nfs::gssd_use_gss_proxy=true' do
            let(:params) {{
              :secure_nfs => true
              # nfs::gssd_use_gss_proxy default is true
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::base::config') }
            it { is_expected.to create_concat__fragment('nfs_conf_gssd').with( {
              :target  => '/etc/nfs.conf',
              :content => <<~EOM

                [gssd]
                  avoid-dns = true
                  limit-to-legacy-enctypes = false
                  use-gss-proxy = true
                EOM
            } ) }

            if os_facts[:os][:release][:major].to_i < 8
              it { is_expected.to create_concat__fragment('nfs_gss_use_proxy').with( {
                :target  => '/etc/sysconfig/nfs',
                :content => "GSS_USE_PROXY=yes"
              } ) }

              it { is_expected.to_not create_concat__fragment('nfs_GSSDARGS') }
            end

            it { is_expected.to create_systemd__dropin_file('simp_unit.conf').with( {
              :unit    => 'gssproxy.service',
              :content => <<~EOM
                # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
                # at the next puppet run.

                [Unit]

                PartOf=nfs-utils.service
                EOM
            } ) }
          end

          context "when nfs::custom_nfs_conf_opts has 'gssd' key" do
            let(:params) {{
              :secure_nfs           => true,
              :custom_nfs_conf_opts => {
                'gssd' => {
                  'use-memcache' => true
                }
              }
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::base::config') }
            it { is_expected.to create_concat__fragment('nfs_conf_gssd').with( {
              :target  => '/etc/nfs.conf',
              :content => <<~EOM

                [gssd]
                  avoid-dns = true
                  limit-to-legacy-enctypes = false
                  use-gss-proxy = true
                  use-memcache = true
                EOM
            } ) }
          end

          if os_facts[:os][:release][:major].to_i < 8
            context "when nfs::custom_daemon_args has 'GSSDARGS' key" do
              let(:params) {{
                :secure_nfs         => true,
                :custom_daemon_args => { 'GSSDARGS' => '-v' }
              }}

              it { is_expected.to compile.with_all_deps }
              it { is_expected.to create_class('nfs::base::config') }
              it { is_expected.to create_concat__fragment('nfs_GSSDARGS').with( {
                :target  => '/etc/sysconfig/nfs',
                :content => 'GSSDARGS="-v"'
              } ) }
            end
          end
        end

        context 'when nfs::nfsv3=true' do
          context 'with default NFSv3-related nfs parameters' do
            let(:params) {{ :nfsv3 => true }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::base::config') }
            it { is_expected.to create_concat__fragment('nfs_conf_lockd').with( {
              :target  => '/etc/nfs.conf',
              :content => <<~EOM

                [lockd]
                  port = 32803
                  udp-port = 32769
                EOM
            } ) }

            it { is_expected.to create_concat__fragment('nfs_conf_sm_notify').with( {
              :target  => '/etc/nfs.conf',
              :content => <<~EOM

                [sm-notify]
                  outgoing-port = 2021
                EOM
            } ) }

            it { is_expected.to create_concat__fragment('nfs_conf_statd').with( {
              :target  => '/etc/nfs.conf',
              :content => <<~EOM

                [statd]
                  outgoing-port = 2020
                  port = 662
                EOM
            } ) }

            it { is_expected.to create_file('/etc/modprobe.d/lockd.conf').with( {
              :owner   => 'root',
              :group   => 'root',
              :mode    => '0640',
              :content => <<~EOM
                # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
                # at the next puppet run.
                #
                # Set the TCP port that the NFS lock manager should use.
                # port must be a valid TCP port value (1-65535).
                options lockd nlm_tcpport=32803

                # Set the UDP port that the NFS lock manager should use.
                # port must be a valid UDP port value (1-65535).
                options lockd nlm_udpport=32769
                EOM
            } ) }
          end

          context "when nfs::custom_nfs_conf_opts has 'lockd' key" do
            let(:params) {{
              :nfsv3                => true,
              :custom_nfs_conf_opts => {
                'lockd' => {
                  # this isn't a real option yet, but currently only
                  # two options available are being set
                  'debug' => 'all'
                }
              }
            }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::base::config') }
            it { is_expected.to create_concat__fragment('nfs_conf_lockd').with( {
              :target  => '/etc/nfs.conf',
              :content => <<~EOM

                [lockd]
                  debug = all
                  port = 32803
                  udp-port = 32769
                EOM
            } ) }
          end

          context "when nfs::custom_nfs_conf_opts has 'sm-notify' key" do
            let(:params) {{
              :nfsv3                => true,
              :custom_nfs_conf_opts => {
                'sm-notify' => {
                  'retry-time' => 10
                }
              }
            }}

            it { is_expected.to create_concat__fragment('nfs_conf_sm_notify').with( {
              :target  => '/etc/nfs.conf',
              :content => <<~EOM

                [sm-notify]
                  outgoing-port = 2021
                  retry-time = 10
                EOM
            } ) }
          end

          context "when nfs::custom_nfs_conf_opts has 'statd' key" do
            let(:params) {{
              :nfsv3                => true,
              :custom_nfs_conf_opts => {
                'statd' => {
                  'state-directory-path' => '/some/path'
                }
              }
            }}

            it { is_expected.to create_concat__fragment('nfs_conf_statd').with( {
              :target  => '/etc/nfs.conf',
              :content => <<~EOM

                [statd]
                  outgoing-port = 2020
                  port = 662
                  state-directory-path = /some/path
                EOM
            } ) }
          end

          if os_facts[:os][:release][:major].to_i < 8
            context "when nfs::custom_daemon_args has 'SMNOTIFYARGS' key" do
              let(:params) {{
                :nfsv3              => true,
                :custom_daemon_args => { 'SMNOTIFYARGS' => '-f' }
              }}

              it { is_expected.to compile.with_all_deps }
              it { is_expected.to create_class('nfs::base::config') }
              it { is_expected.to create_concat__fragment('nfs_SMNOTIFYARGS').with( {
                :target  => '/etc/sysconfig/nfs',
                :content => 'SMNOTIFYARGS="-f"'
              } ) }
            end

            context "when nfs::custom_daemon_args has 'STATDARG' key" do
              let(:params) {{
                :nfsv3              => true,
                :custom_daemon_args => { 'STATDARG' => '--no-syslog' }
              }}

              it { is_expected.to compile.with_all_deps }
              it { is_expected.to create_class('nfs::base::config') }
              it { is_expected.to create_concat__fragment('nfs_STATDARG').with( {
                :target  => '/etc/sysconfig/nfs',
                :content => 'STATDARG="--no-syslog"'
              } ) }
            end
          end
        end

        context 'with nfs::idmapd=true' do
          let(:params) {{ :idmapd => true }}

          it { is_expected.to create_class('nfs::idmapd::config') }
        end
      end
    end
  end
end
