require 'spec_helper'

describe 'nfs::server::export' do

  def mock_selinux_false_facts(os_facts)
    os_facts[:selinux] = false
    os_facts[:os][:selinux][:config_mode] = 'disabled'
    os_facts[:os][:selinux][:current_mode] = 'disabled'
    os_facts[:os][:selinux][:enabled] = false
    os_facts[:os][:selinux][:enforced] = false
    os_facts
  end

  def mock_selinux_enforcing_facts(os_facts)
    os_facts[:selinux] = true
    os_facts[:os][:selinux][:config_mode] = 'enforcing'
    os_facts[:os][:selinux][:config_policy] = 'targeted'
    os_facts[:os][:selinux][:current_mode] = 'enforcing'
    os_facts[:os][:selinux][:enabled] = true
    os_facts[:os][:selinux][:enforced] = true
    os_facts
  end


  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:pre_condition) { 'class { "nfs": is_server => true }' }

      let(:facts) {
        os_facts.merge( {
          # to workaround service provider issues related to masking haveged
          # when tests are run on GitLab runners which are docker containers
          :haveged__rngd_enabled => false,
          :ipv6_enabled          => true
        } )
      }

      let(:title) { 'nfs_test' }
      base_params = {
        :export_path => '/foo/bar/baz',
        :clients     => ['0.0.0.0/0']
      }

      context 'with default parameters' do
        let(:params) { base_params }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('nfs::server') }

        it {
          content = <<~EOM
            /foo/bar/baz 0.0.0.0/0(sync,security_label,sec=sys,anonuid=65534,anongid=65534)
            /foo/bar/baz 127.0.0.1(sync,security_label,sec=sys,anonuid=65534,anongid=65534,insecure)
            /foo/bar/baz ::1(sync,security_label,sec=sys,anonuid=65534,anongid=65534,insecure)
          EOM

          is_expected.to create_concat__fragment("nfs_#{title}_export").with_content(content)
        }
        it { is_expected.to contain_selboolean('nfsd_anon_write') }
      end

      context 'with parameters different from defaults' do
        let(:params) { base_params.merge({
          :insecure       => true,
          :rw             => true,
          :async          => true,
          :no_wdelay      => true,
          :nohide         => true,
          :crossmnt       => true,
          :subtree_check  => true,
          :insecure_locks => true,
          :nordirplus     => true,
          :pnfs           => true,
          :security_label => false,
          :sec            => ['sys', 'krb5p'],
          :no_root_squash => true,
          :all_squash     => true,
          :anonuid        => 65520,
          :anongid        => 65530
        }) }

        it { is_expected.to contain_class('nfs::server') }

        it {
          content = <<~EOM
            /foo/bar/baz 0.0.0.0/0(insecure,rw,async,no_wdelay,nohide,crossmnt,subtree_check,insecure_locks,nordirplus,pnfs,sec=sys:krb5p,no_root_squash,all_squash,anonuid=65520,anongid=65530)
            /foo/bar/baz 127.0.0.1(insecure,rw,async,no_wdelay,nohide,crossmnt,subtree_check,insecure_locks,nordirplus,pnfs,sec=sys:krb5p,no_root_squash,all_squash,anonuid=65520,anongid=65530)
            /foo/bar/baz ::1(insecure,rw,async,no_wdelay,nohide,crossmnt,subtree_check,insecure_locks,nordirplus,pnfs,sec=sys:krb5p,no_root_squash,all_squash,anonuid=65520,anongid=65530)
        EOM

          is_expected.to create_concat__fragment("nfs_#{title}_export").with_content(content)
        }
      end

      context 'with optional parameters set and mountpoint is a path' do
        let(:params) { base_params.merge({
          :comment    => 'some comment',
          :mountpoint => '/mount/point/path',
          :fsid       => 'test_vsid',
          :refer      => ['/path@test_refer1', '/path@test_refer2'],
          :replicas   => ['/path@test_replica1', '/path@test_replica2']
        }) }

        it { is_expected.to compile.with_all_deps }

        it {
          content = <<~EOM
            # some comment
            /foo/bar/baz 0.0.0.0/0(sync,mp=/mount/point/path,fsid=test_vsid,refer=/path@test_refer1:/path@test_refer2,replicas=/path@test_replica1:/path@test_replica2,security_label,sec=sys,anonuid=65534,anongid=65534)
            /foo/bar/baz 127.0.0.1(sync,mp=/mount/point/path,fsid=test_vsid,refer=/path@test_refer1:/path@test_refer2,replicas=/path@test_replica1:/path@test_replica2,security_label,sec=sys,anonuid=65534,anongid=65534,insecure)
            /foo/bar/baz ::1(sync,mp=/mount/point/path,fsid=test_vsid,refer=/path@test_refer1:/path@test_refer2,replicas=/path@test_replica1:/path@test_replica2,security_label,sec=sys,anonuid=65534,anongid=65534,insecure)
          EOM

          is_expected.to create_concat__fragment("nfs_#{title}_export").with_content(content)
        }
      end

      context 'with mountpoint is a true' do
        let(:params) { base_params.merge({ :mountpoint => true }) }
        it { is_expected.to compile.with_all_deps }

        it {
          content = <<~EOM
            /foo/bar/baz 0.0.0.0/0(sync,mp,security_label,sec=sys,anonuid=65534,anongid=65534)
            /foo/bar/baz 127.0.0.1(sync,mp,security_label,sec=sys,anonuid=65534,anongid=65534,insecure)
            /foo/bar/baz ::1(sync,mp,security_label,sec=sys,anonuid=65534,anongid=65534,insecure)
        EOM

          is_expected.to create_concat__fragment("nfs_#{title}_export").with_content(content)
        }
      end

      context 'with custom set' do
        let(:params) { base_params.merge({ :custom => 'some custom setting' }) }
        it { is_expected.to compile.with_all_deps }

        it {
          content = <<~EOM
            /foo/bar/baz 0.0.0.0/0(somecustomsetting)
            /foo/bar/baz 127.0.0.1(somecustomsetting,insecure)
            /foo/bar/baz ::1(somecustomsetting,insecure)
          EOM

          is_expected.to create_concat__fragment("nfs_#{title}_export").with_content(content)
        }
      end

      context "with selinux disabled and 'sys' in 'sec' parameter" do
        let(:params) { base_params }
        let(:facts) {
          os_facts.merge( {
            # to workaround service provider issues related to masking haveged
            # when tests are run on GitLab runners which are docker containers
            :haveged__rngd_enabled => false,
          })
          mock_selinux_false_facts(os_facts)
        }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to_not contain_selboolean('nfsd_anon_write') }
      end
    end
  end
end
