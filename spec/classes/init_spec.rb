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
              :ensure  => 'latest',
              :require => 'Class[Nfs::Lvm2]'
            })
          }
          it { is_expected.to contain_package('nfs4-acl-tools').with_ensure('latest') }
          it { is_expected.to contain_class('nfs::client') }
        end

        if os =~ /(?:redhat|centos)-(\d+)/
          it_behaves_like "a fact set"

          if $1.to_i < 7
            it { is_expected.to create_file('/etc/sysconfig/nfs').with({
              :content => /MOUNTD_PORT=20048/,
              })
            }
          else
            it { is_expected.to create_file('/etc/sysconfig/nfs') }
          end
        end
      end
    end
  end
end
