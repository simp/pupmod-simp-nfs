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
          :client => ['0.0.0.0/0']
        }

        let(:params) { base_params }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('nfs::server') }
        it { is_expected.to create_concat_fragment("nfs+#{title}.export") }
        it { is_expected.to_not contain_selboolean('nfs_anon_write') }


        context 'when sec includes "sys"' do
          let(:params) {
            p = base_params.dup
            p[:sec] = ['sys','krb5']

            p
          }

          it { is_expected.to compile.with_all_deps }

          if ['RedHat','CentOS'].include?(facts[:operatingsystem]) && facts[:operatingsystemmajrelease].to_s > '6'
            it { is_expected.to contain_selboolean('nfs_anon_write') }
          else
            it { is_expected.to_not contain_selboolean('nfs_anon_write') }
          end
        end
      end
    end
  end
end
