require 'spec_helper'

describe 'nfs::server::export' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:pre_condition) { 'class { "nfs": is_server => true }' }

        let(:facts) { facts }
        let(:title) { 'nfs_test' }
        base_params = {
          :export_path => '/foo/bar/baz',
          :clients     => ['0.0.0.0/0']
        }


        context 'with default parameters' do
          let(:params) { base_params }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('nfs::server') }
          it { is_expected.to create_concat__fragment("nfs_#{title}_export").with_content( <<EOM
/foo/bar/baz 0.0.0.0/0(sync,sec=sys,anonuid=65534,anongid=65534)
/foo/bar/baz 127.0.0.1(sync,sec=sys,anonuid=65534,anongid=65534,insecure)
EOM
          ) }
        end

        context 'with optional parameters set and mountpoint is a path' do
          let(:params) { base_params.merge({
            :comment    => 'some comment',
            :mountpoint => '/mount/point/path',
            :fsid       => 'test_vsid',
            :refer      => ['/path@test_refer']
          }) }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_concat__fragment("nfs_#{title}_export").with_content( <<EOM
# some comment
/foo/bar/baz 0.0.0.0/0(sync,mp=/mount/point/path,fsid=test_vsid,refer=/path@test_refer,sec=sys,anonuid=65534,anongid=65534)
/foo/bar/baz 127.0.0.1(sync,mp=/mount/point/path,fsid=test_vsid,refer=/path@test_refer,sec=sys,anonuid=65534,anongid=65534,insecure)
EOM
          ) }
        end

        context 'with mountpoint is a true' do
          let(:params) { base_params.merge({ :mountpoint => true }) }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_concat__fragment("nfs_#{title}_export").with_content( <<EOM
/foo/bar/baz 0.0.0.0/0(sync,mp,sec=sys,anonuid=65534,anongid=65534)
/foo/bar/baz 127.0.0.1(sync,mp,sec=sys,anonuid=65534,anongid=65534,insecure)
EOM
          ) }
        end

        context 'with custom set' do
          let(:params) { base_params.merge({ :custom => 'some custom setting' }) }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_concat__fragment("nfs_#{title}_export").with_content( <<EOM
/foo/bar/baz 0.0.0.0/0(somecustomsetting)
/foo/bar/baz 127.0.0.1(somecustomsetting,insecure)
EOM
          ) }
        end

        context 'when sec includes "sys"' do
          let(:params) {
            p = base_params.dup
            p[:sec] = ['sys','krb5']

            p
          }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_concat__fragment("nfs_#{title}_export").with_content( <<EOM
/foo/bar/baz 0.0.0.0/0(sync,sec=sys:krb5,anonuid=65534,anongid=65534)
/foo/bar/baz 127.0.0.1(sync,sec=sys:krb5,anonuid=65534,anongid=65534,insecure)
EOM
          ) }

          if facts[:operatingsystemmajrelease].to_s > '6'
            it { is_expected.to contain_selboolean('nfsd_anon_write') }
          else
            it { is_expected.to_not contain_selboolean('nfsd_anon_write') }
          end
        end

        context 'with selinux disabled' do
          let(:params) { base_params }
          let(:facts) { facts.merge({:selinux => false})}
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to_not contain_selboolean('nfsd_anon_write') }
        end
      end
    end
  end
end
