require 'spec_helper'

describe 'nfs' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts){ facts }

        shared_examples_for "a fact set" do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('nfs') }
          it { is_expected.to contain_package('nfs-utils').with({
              :ensure  => 'latest'
            })
          }
          it { is_expected.to contain_package('nfs4-acl-tools').with_ensure('latest') }
          it { is_expected.to contain_class('nfs::client') }
        end

        if os =~ /(?:redhat|centos)-(\d+)/
          it_behaves_like "a fact set"
          it { is_expected.to contain_concat_fragment('sysconfig_nfs+init').with_content(%r(MOUNTD_PORT=20048)) }
          it { is_expected.to create_file('/etc/sysconfig/nfs') }
        end
      end
    end
  end
end
