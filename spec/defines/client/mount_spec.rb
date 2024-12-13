require 'spec_helper'

describe 'nfs::client::mount' do
  shared_examples_for 'a base client mount define' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('nfs::client') }
    it { is_expected.to create_nfs__client__mount(title) }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) do
        # to workaround service provider issues related to masking haveged
        # when tests are run on GitLab runners which are docker containers
        os_facts.merge({ haveged__rngd_enabled: false })
      end

      let(:title) { '/net/apps' }
      let(:nfs_server) { '1.2.3.4' }

      let(:pre_condition) do
        # Mask 'simplib::host_is_me' with mock version for testing
        'function simplib::host_is_me($host) { return false }'
      end

      context 'with default parameters' do
        let(:params) do
          {
            nfs_server: nfs_server,
         remote_path: title
          }
        end

        context 'with defaults for nfs and nfs::client' do
          include_examples 'a base client mount define'
          it { is_expected.not_to contain_service('remote-fs.target') }
          it 'uses nfs & nfs::client defaults for unspecified connection params' do
            is_expected.to create_nfs__client__mount__connection(title).with({
                                                                               nfs_server: params[:nfs_server],
              nfs_version: 4,
              nfsd_port: 2049, # from nfs
              firewall: false, # from nfs
              stunnel: false, # from nfs::client
              stunnel_nfsd_port: 20_490, # from nfs
              stunnel_socket_options: ['l:TCP_NODELAY=1', 'r:TCP_NODELAY=1'], # from nfs::client
              stunnel_verify: 2, # from nfs::client
              stunnel_wantedby: ['remote-fs-pre.target'], # from nfs::client
              tcpwrappers: false # from nfs
                                                                             })
          end

          it { is_expected.to contain_class('autofs') }
          it {
            is_expected.to contain_autofs__map(title).with({
                                                             mount_point: '/-',
              mappings: {
                'key'      => title,
                'options'  => '-_netdev,nfsvers=4,port=2049,soft,sec=sys',
                'location' => "#{params[:nfs_server]}:#{params[:remote_path]}"
              }
                                                           })
          }
        end

        context 'with explicit nfs and nfs::client parameters' do
          let(:hieradata) { 'nfs_client_mount_custom' }

          include_examples 'a base client mount define'
          it 'uses nfs & nfs::client params for unspecified connection params' do
            is_expected.to create_nfs__client__mount__connection(title).with({
                                                                               nfs_server: params[:nfs_server],
              nfs_version: 4,
              nfsd_port: 2050, # from nfs
              firewall: true, # from nfs
              stunnel: true, # from nfs::client
              stunnel_nfsd_port: 20_500, # from nfs
              stunnel_socket_options: ['l:TCP_NODELAY=2', 'r:TCP_NODELAY=2'], # from nfs::client
              stunnel_verify: 1, # from nfs::client
              stunnel_wantedby: ['remote-fs-pre.target', 'some-other.service'], # from nfs::client
              tcpwrappers: true # from nfs
                                                                             })
          end
        end
      end # context 'with default parameters' do

      context 'with autofs' do
        let(:base_params) do
          {
            nfs_server: nfs_server,
         remote_path: title,
         autofs: true
          }
        end

        context 'with direct map' do
          context 'with NFSv3' do
            let(:pre_condition) { "class { 'nfs': nfsv3 => true }" }
            let(:params) { base_params.merge({ nfs_version: 3, stunnel: false }) }

            include_examples 'a base client mount define'
            it { is_expected.to create_nfs__client__mount__connection(title).with_nfs_version(3) }
            it { is_expected.to contain_class('autofs') }
            it {
              is_expected.to contain_autofs__map(title).with({
                                                               mount_point: '/-',
                mappings: {
                  'key'      => title,
                  'options'  => '-_netdev,nfsvers=3,port=2049,soft',
                  'location' => "#{params[:nfs_server]}:#{params[:remote_path]}"
                }
                                                             })
            }
          end

          context 'with NFSV4 and stunnel' do
            let(:params) do
              base_params.merge({
                                  nfsd_port: 2050,
                stunnel: true,
                stunnel_nfsd_port: 20_500,
                stunnel_socket_options: ['l:TCP_NODELAY=2', 'r:TCP_NODELAY=2'],
                stunnel_verify: 1,
                stunnel_wantedby: ['remote-fs-pre.target', 'some-other.service']
                                })
            end

            include_examples 'a base client mount define'
            it {
              is_expected.to create_nfs__client__mount__connection(title).with({
                                                                                 nfs_server: params[:nfs_server],
              nfs_version: 4,
              nfsd_port: 2050,
              stunnel: true,
              stunnel_nfsd_port: 20_500,
              stunnel_socket_options: ['l:TCP_NODELAY=2', 'r:TCP_NODELAY=2'],
              stunnel_verify: 1,
              stunnel_wantedby: ['remote-fs-pre.target', 'some-other.service']
                                                                               })
            }

            it { is_expected.to contain_class('autofs') }
            it {
              is_expected.to contain_autofs__map(title).with({
                                                               mount_point: '/-',
                mappings: {
                  'key'      => title,
                  'options'  => '-_netdev,nfsvers=4,port=2050,soft,sec=sys,proto=tcp',
                  'location' => "127.0.0.1:#{params[:remote_path]}"
                }
                                                             })
            }

            it {
              is_expected.to contain_stunnel__instance("nfs_#{params[:nfs_server]}:2050_client_nfsd")
                .that_notifies('Exec[autofs_reload]')
            }
          end

          context 'with NFSV4 without stunnel' do
            let(:params) { base_params.merge({ stunnel: false }) }

            include_examples 'a base client mount define'
            it {
              is_expected.to create_nfs__client__mount__connection(title).with({
                                                                                 nfs_server: params[:nfs_server],
              nfs_version: 4,
              nfsd_port: 2049,
              stunnel: false
                                                                               })
            }

            it { is_expected.to contain_class('autofs') }
            it {
              is_expected.to contain_autofs__map(title).with({
                                                               mount_point: '/-',
                mappings: {
                  'key'      => title,
                  'options'  => '-_netdev,nfsvers=4,port=2049,soft,sec=sys',
                  'location' => "#{params[:nfs_server]}:#{params[:remote_path]}"
                }
                                                             })
            }
          end
        end # context 'with direct map' do

        context 'with indirect map' do
          context 'with NFSv3' do
            let(:pre_condition) { "class { 'nfs': nfsv3 => true }" }
            let(:params) do
              base_params.merge({
                                  nfs_version: 3,
                autofs_indirect_map_key: 'some_dir',

                # this will be ignored
                stunnel: true
                                })
            end

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_autofs__map(title).with({
                                                               mount_point: title,
                mappings: [ {
                  'key'      => params[:autofs_indirect_map_key],
                  'options'  => '-_netdev,nfsvers=3,port=2049,soft',
                  'location' => "#{params[:nfs_server]}:#{params[:remote_path]}"
                } ]
                                                             })
            }
          end

          context 'with NFSV4 and stunnel' do
            let(:params) do
              base_params.merge({
                                  autofs_indirect_map_key: 'some_dir',
                stunnel: true
                                })
            end

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_autofs__map(title).with({
                                                               mount_point: title,
                mappings: [ {
                  'key'      => params[:autofs_indirect_map_key],
                  'options'  => '-_netdev,nfsvers=4,port=2049,soft,sec=sys,proto=tcp',
                  'location' => "127.0.0.1:#{params[:remote_path]}"
                } ]
                                                             })
            }
          end

          context 'with NFSV4 without stunnel' do
            let(:params) do
              base_params.merge({
                                  autofs_indirect_map_key: 'some_dir',
                stunnel: false
                                })
            end

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_autofs__map(title).with({
                                                               mount_point: title,
                mappings: [ {
                  'key'      => params[:autofs_indirect_map_key],
                  'options'  => '-_netdev,nfsvers=4,port=2049,soft,sec=sys',
                  'location' => "#{params[:nfs_server]}:#{params[:remote_path]}"
                } ]
                                                             })
            }
          end

          context 'with key substitution' do
            let(:params) do
              base_params.merge({
                                  autofs_indirect_map_key: '*',
                autofs_add_key_subst: true
                                })
            end

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_autofs__map(title).with({
                                                               mount_point: title,
                mappings: [ {
                  'key'      => params[:autofs_indirect_map_key],
                  'options'  => '-_netdev,nfsvers=4,port=2049,soft,sec=sys',
                  'location' => "#{params[:nfs_server]}:#{params[:remote_path]}/&"
                } ]
                                                             })
            }
          end
        end
      end # context 'with autofs' do

      context 'without autofs' do
        let(:base_params) do
          {
            nfs_server: nfs_server,
         remote_path: title,
         autofs: false
          }
        end

        context 'with NFSv3' do
          let(:pre_condition) { "class { 'nfs': nfsv3 => true }" }
          let(:params) { base_params.merge({ nfs_version: 3, stunnel: false }) }

          include_examples 'a base client mount define'
          it { is_expected.to create_nfs__client__mount__connection(title).with_nfs_version(3) }
          it { is_expected.to contain_service('remote-fs.target').with_enable(true) }
          it {
            is_expected.to contain_mount(title).with({
                                                       ensure: 'mounted',
            atboot: true,
            device: "#{params[:nfs_server]}:#{params[:remote_path]}",
            fstype: 'nfs',
            options: '_netdev,nfsvers=3,port=2049,soft',
            remounts: false
                                                     })
          }

          it { is_expected.not_to contain_class('autofs') }
          it { is_expected.not_to contain_autofs__map(title) }
        end

        context 'with NFSV4 and stunnel' do
          let(:params) { base_params.merge({ stunnel: true }) }

          include_examples 'a base client mount define'
          it { is_expected.to create_nfs__client__mount__connection(title).with_nfs_version(4) }
          it { is_expected.to contain_service('remote-fs.target').with_enable(true) }
          it {
            is_expected.to contain_mount(title).with({
                                                       ensure: 'mounted',
            atboot: true,
            device: "127.0.0.1:#{params[:remote_path]}",
            fstype: 'nfs',
            options: '_netdev,nfsvers=4,port=2049,soft,sec=sys,proto=tcp',
            remounts: false
                                                     })
          }

          it { is_expected.not_to contain_class('autofs') }
          it { is_expected.not_to contain_autofs__map(title) }
        end

        context 'with NFSV4 without stunnel' do
          let(:params) { base_params.merge({ stunnel: false }) }

          include_examples 'a base client mount define'
          it { is_expected.to create_nfs__client__mount__connection(title).with_nfs_version(4) }
          it { is_expected.to contain_service('remote-fs.target').with_enable(true) }
          it {
            is_expected.to contain_mount(title).with({
                                                       ensure: 'mounted',
            atboot: true,
            device: "#{params[:nfs_server]}:#{params[:remote_path]}",
            fstype: 'nfs',
            options: '_netdev,nfsvers=4,port=2049,soft,sec=sys',
            remounts: false
                                                     })
          }

          it { is_expected.not_to contain_class('autofs') }
          it { is_expected.not_to contain_autofs__map(title) }
        end

        context 'with at_boot=false and ensure=present' do
          let(:params) do
            base_params.merge({
                                at_boot: false,
              ensure: 'present',
              stunnel: false
                              })
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_nfs__client__mount__connection(title).with_nfs_version(4) }
          it { is_expected.to contain_service('remote-fs.target').with_enable(true) }
          it {
            is_expected.to contain_mount(title).with({
                                                       ensure: 'present',
            atboot: false,
            device: "#{params[:nfs_server]}:#{params[:remote_path]}",
            fstype: 'nfs',
            options: '_netdev,nfsvers=4,port=2049,soft,sec=sys',
            remounts: false
                                                     })
          }
        end
      end # context 'without autofs' do

      context 'with other autodetect_remote permutations' do
        let(:pre_condition) do
          # Mask 'simplib::host_is_me' with mock version for testing
          'function simplib::host_is_me($host) { return true }'
        end

        let(:base_params) do
          {
            nfs_server: nfs_server,
         remote_path: title,
         stunnel: false,
         autofs: false # same logic exercised for static and auto mounts
          }
        end

        context 'autodetect_remote=false and simplib::host_is_me($host)=true' do
          let(:params) { base_params.merge({ autodetect_remote: false }) }

          include_examples 'a base client mount define'
          it { is_expected.to create_nfs__client__mount__connection(title).with_nfs_version(4) }
          it { is_expected.to contain_service('remote-fs.target').with_enable(true) }
          it 'does not use localhost for mount' do
            is_expected.to contain_mount(title).with({
                                                       ensure: 'mounted',
              atboot: true,
              device: "#{params[:nfs_server]}:#{params[:remote_path]}",
              fstype: 'nfs',
              options: '_netdev,nfsvers=4,port=2049,soft,sec=sys',
              remounts: false
                                                     })
          end
        end

        context 'autodetect_remote=true and simplib::host_is_me($host)=true' do
          let(:params) { base_params.merge({ autodetect_remote: true }) }

          it { is_expected.to contain_service('remote-fs.target').with_enable(true) }
          it 'uses localhost for mount' do
            is_expected.to contain_mount(title).with({
                                                       ensure: 'mounted',
              atboot: true,
              device: "127.0.0.1:#{params[:remote_path]}",
              fstype: 'nfs',
              options: '_netdev,nfsvers=4,port=2049,soft,sec=sys',
              remounts: false
                                                     })
          end
        end
      end # context 'with other autodetect_remote permutations' do

      context 'errors' do
        context 'title is not a full path' do
          let(:params) do
            {
              nfs_server: '1.2.3.4',
           remote_path: 'home'
            }
          end

          it { is_expected.not_to compile.with_all_deps }
        end

        context 'when nfs_version=3 but nfs::nfsv3=false' do
          let(:params) do
            {
              nfs_server: '1.2.3.4',
           remote_path: '/home',
           nfs_version: 3
            }
          end

          it { is_expected.not_to compile.with_all_deps }
        end
      end
    end # context "on #{os}"
  end # on_supported_os.each
end # describe
