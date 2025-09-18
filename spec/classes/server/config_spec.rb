require 'spec_helper'

# Testing private nfs::server::config class via nfs class
describe 'nfs' do
  describe 'private nfs::server::config' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          os_facts.merge(haveged__rngd_enabled: false)
        end

        context 'with default nfs and nfs::server parameters' do
          let(:params) { { is_server: true } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::server::config') }
          it { is_expected.not_to create_concat__fragment('nfs_conf_exportfs') }
          it {
            is_expected.to create_concat__fragment('nfs_conf_mountd').with(
              target: '/etc/nfs.conf',
              content: <<~EOM,

                [mountd]
                  port = 20048
              EOM
            )
          }

          it {
            is_expected.to create_concat__fragment('nfs_conf_nfsd').with(
              target: '/etc/nfs.conf',
              content: <<~EOM,

                [nfsd]
                  port = 2049
                  vers2 = false
                  vers3 = false
                  vers4 = true
                  vers4.0 = false
                  vers4.1 = true
                  vers4.2 = true
              EOM
            )
          }

          it { is_expected.not_to create_concat__fragment('nfs_conf_nfsdcltrack') }

          # the next 4 omissions are true for EL > 7, always, and for EL7 in
          # this case, because there is no custom config
          it { is_expected.not_to create_concat__fragment('nfs_RPCIDMAPDARGS') }
          it { is_expected.not_to create_concat__fragment('nfs_RPCMOUNTDARGS') }
          it { is_expected.not_to create_concat__fragment('nfs_RPCNFSDCOUNT') }
          it { is_expected.not_to create_concat__fragment('nfs_RPCNFSDARGS') }

          it {
            is_expected.to create_file('/etc/sysconfig/rpc-rquotad').with(
              owner: 'root',
              group: 'root',
              mode: '0644',
              content: <<~EOM,
                # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
                # at the next puppet run.
                #
                RPCRQUOTADOPTS="-p 875"
              EOM
            )
          }

          it {
            is_expected.to create_concat('/etc/exports').with(
              owner: 'root',
              group: 'root',
              mode: '0644',
            )
          }

          it {
            is_expected.to create_systemd__unit_file('simp_etc_exports.path').with(
              enable: true,
              active: true,
              content: <<~EOM,
                # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
                # at the next puppet run.

                [Path]
                Unit=simp_etc_exports.service
                PathChanged=/etc/exports

                [Install]
                WantedBy=multi-user.target
              EOM
            )
          }

          it {
            is_expected.to create_systemd__unit_file('simp_etc_exports.service').with(
              enable: true,
              content: <<~EOM,
                # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
                # at the next puppet run.

                [Service]
                Type=simple
                ExecStart=/usr/sbin/exportfs -ra
              EOM
            )
          }
        end

        context 'when nfsv3 only enabled for the NFS client' do
          let(:hieradata) { 'nfs_nfsv3_and_not_nfs_server_nfsd_vers3' }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::server::config') }
          it {
            is_expected.to create_concat__fragment('nfs_conf_nfsd').with(
              target: '/etc/nfs.conf',
              content: <<~EOM,

                [nfsd]
                  port = 2049
                  vers2 = false
                  vers3 = false
                  vers4 = true
                  vers4.0 = false
                  vers4.1 = true
                  vers4.2 = true
              EOM
            )
          }
        end

        context 'when stunnel enabled' do
          context 'when nfsd tcp and udp are not specified in custom config' do
            let(:params) do
              {
                is_server: true,
                stunnel: true,
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server::config') }
            it 'explicitlies enabled tcp and disable udp in nfsd config' do
              is_expected.to create_concat__fragment('nfs_conf_nfsd').with(
                target: '/etc/nfs.conf',
                content: <<~EOM,

                  [nfsd]
                    port = 2049
                    tcp = true
                    udp = false
                    vers2 = false
                    vers3 = false
                    vers4 = true
                    vers4.0 = false
                    vers4.1 = true
                    vers4.2 = true
                EOM
              )
            end
          end

          context 'when nfsd tcp and udp are specified with bad settings for stunnel in custom config' do
            let(:params) do
              {
                is_server: true,
                stunnel: true,
                custom_nfs_conf_opts: {
                  'nfsd' => {
                    # ask for protocol settings that are the opposite of those
                    # required for stunnnel
                    'tcp' => false,
                    'udp' => true,
                  },
                },
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server::config') }
            it 'overrides tcp and udp settings in nfsd config' do
              is_expected.to create_concat__fragment('nfs_conf_nfsd').with(
                target: '/etc/nfs.conf',
                content: <<~EOM,

                  [nfsd]
                    port = 2049
                    tcp = true
                    udp = false
                    vers2 = false
                    vers3 = false
                    vers4 = true
                    vers4.0 = false
                    vers4.1 = true
                    vers4.2 = true
                EOM
              )
            end
          end
        end

        context 'with nfs::custom_nfs_conf_opts set' do
          context "when nfs::custom_nfs_conf_opts has 'exportfs' key" do
            let(:params) do
              {
                is_server: true,
                custom_nfs_conf_opts: {
                  'exportfs' => {
                    'debug' => 'all',
                  },
                },
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server::config') }
            it {
              is_expected.to create_concat__fragment('nfs_conf_exportfs').with(
                target: '/etc/nfs.conf',
                content: <<~EOM,

                  [exportfs]
                    debug = all
                EOM
              )
            }
          end

          context "when nfs::custom_nfs_conf_opts has 'mountd' key" do
            let(:params) do
              {
                is_server: true,
                custom_nfs_conf_opts: {
                  'mountd' => {
                    'threads' => 16,
                  },
                },
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server::config') }
            it {
              is_expected.to create_concat__fragment('nfs_conf_mountd').with(
                target: '/etc/nfs.conf',
                content: <<~EOM,

                  [mountd]
                    port = 20048
                    threads = 16
                EOM
              )
            }
          end

          context "when nfs::custom_nfs_conf_opts has 'nfsd' key" do
            let(:params) do
              {
                is_server: true,
                custom_nfs_conf_opts: {
                  'nfsd' => {
                    'threads' => 32,
                  },
                },
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server::config') }
            it {
              is_expected.to create_concat__fragment('nfs_conf_nfsd').with(
                target: '/etc/nfs.conf',
                content: <<~EOM,

                  [nfsd]
                    port = 2049
                    threads = 32
                    vers2 = false
                    vers3 = false
                    vers4 = true
                    vers4.0 = false
                    vers4.1 = true
                    vers4.2 = true
                EOM
              )
            }
          end

          if os_facts[:os][:release][:major].to_i < 8
            context "when nfs::custom_nfs_conf_opts has 'nfsd' key with 'threads' key on EL7" do
              let(:params) do
                {
                  is_server: true,
                  custom_nfs_conf_opts: {
                    'nfsd' => {
                      'threads' => 32,
                    },
                  },
                }
              end

              it { is_expected.to compile.with_all_deps }
              it { is_expected.to create_class('nfs::server::config') }
              it 'alsoes set RPCNFSDCOUNT in /etc/sysconfig/nfs' do
                is_expected.to create_concat__fragment('nfs_RPCNFSDCOUNT').with(
                  target: '/etc/sysconfig/nfs',
                  content: 'RPCNFSDCOUNT="32"',
                )
              end
            end
          end

          context "when nfs::custom_nfs_conf_opts has 'nfsdcltrack' key" do
            let(:params) do
              {
                is_server: true,
                custom_nfs_conf_opts: {
                  'nfsdcltrack' => {
                    'storagedir' => '/some/path',
                  },
                },
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to create_class('nfs::server::config') }
            it {
              is_expected.to create_concat__fragment('nfs_conf_nfsdcltrack').with(
                target: '/etc/nfs.conf',
                content: <<~EOM,

                  [nfsdcltrack]
                    storagedir = /some/path
                EOM
              )
            }
          end
        end

        if os_facts[:os][:release][:major].to_i < 8
          context 'when nfs::custom_daemon_args set' do
            context "when nfs::custom_daemon_args has 'RCIDMAPDARGS' key" do
              let(:params) do
                {
                  is_server: true,
                  custom_daemon_args: { 'RPCIDMAPDARGS' => '-C' },
                }
              end

              it { is_expected.to compile.with_all_deps }
              it { is_expected.to create_class('nfs::server::config') }
              it {
                is_expected.to create_concat__fragment('nfs_RPCIDMAPDARGS').with(
                  target: '/etc/sysconfig/nfs',
                  content: 'RPCIDMAPDARGS="-C"',
                )
              }
            end

            context "when nfs::custom_daemon_args has 'RPCMOUNTDARGS' key" do
              let(:params) do
                {
                  is_server: true,
                  custom_daemon_args: { 'RPCMOUNTDARGS' => '-f /some/export/file' },
                }
              end

              it { is_expected.to compile.with_all_deps }
              it { is_expected.to create_class('nfs::server::config') }
              it {
                is_expected.to create_concat__fragment('nfs_RPCMOUNTDARGS').with(
                  target: '/etc/sysconfig/nfs',
                  content: 'RPCMOUNTDARGS="-f /some/export/file"',
                )
              }
            end

            context "when nfs::custom_daemon_args has 'RPCNFSDARGS' key" do
              let(:params) do
                {
                  is_server: true,
                  custom_daemon_args: { 'RPCNFSDARGS' => '--syslog' },
                }
              end

              it { is_expected.to compile.with_all_deps }
              it { is_expected.to create_class('nfs::server::config') }
              it {
                is_expected.to create_concat__fragment('nfs_RPCNFSDARGS').with(
                  target: '/etc/sysconfig/nfs',
                  content: 'RPCNFSDARGS="--syslog"',
                )
              }
            end
          end
        end

        context 'when nfs::server::custom_rpcrquotad_opts set' do
          let(:hieradata) { 'nfs_server_custom_rpcrquotad_opts' }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::server::config') }
          it {
            is_expected.to create_file('/etc/sysconfig/rpc-rquotad').with_content(<<~EOM)
              # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
              # at the next puppet run.
              #
              RPCRQUOTADOPTS="--setquota -p 875"
            EOM
          }
        end

        context 'when tcpwrappers enabled' do
          let(:params) do
            {
              is_server: true,
              tcpwrappers: true,
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs::server::config') }
          it { is_expected.to create_class('nfs::server::tcpwrappers') }
        end
      end
    end
  end
end
