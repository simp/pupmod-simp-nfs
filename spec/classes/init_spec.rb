require 'spec_helper'

describe 'nfs' do
  base_facts = {
    "RHEL 6" => {
      :fqdn => 'spec.test',
      :grub_version => '0.97',
      :hardwaremodel => 'x86_64',
      :interfaces => 'lo',
      :ipaddress_lo => '127.0.0.1',
      :lsbmajdistrelease => '6',
      :operatingsystem => 'RedHat',
      :operatingsystemmajrelease => '6',
      :processorcount => 4,
      :uid_min => '500'
    },
    "RHEL 7" => {
      :fqdn => 'spec.test',
      :grub_version => '0.97',
      :hardwaremodel => 'x86_64',
      :interfaces => 'lo',
      :ipaddress_lo => '127.0.0.1',
      :lsbmajdistrelease => '7',
      :operatingsystem => 'RedHat',
      :operatingsystemmajrelease => '7',
      :processorcount => 4,
      :uid_min => '500'
    }
  }

  shared_examples_for "a fact set" do
    it { should create_class('nfs') }
    it { should compile.with_all_deps }
    it { should create_file('/etc/exports') }
    it { should contain_package('nfs-utils').with_ensure('latest') }
    it { should contain_package('nfs4-acl-tools').with_ensure('latest') }
    it { should contain_service('nfslock').with({
        :ensure  => 'running',
        :require => ['Service[rpcbind]', 'Package[nfs-utils]']
      })
    }
    it { should contain_service('rpcbind').with({
        :ensure  => 'running',
        :require => 'Service[rpcidmapd]'
      })
    }
    it { should contain_service('rpcidmapd').with({
        :ensure  => 'running',
        :require => 'Package[nfs-utils]'
      })
    }
    it { should contain_service('rpcgssd').with({
        :ensure  => 'running',
        :require => 'Service[rpcbind]'
      })
    }
    it { should contain_class('nfs::client') }
  end

  describe "RHEL 6" do
    it_behaves_like "a fact set"
    let(:facts) {base_facts['RHEL 6']}
    it { should create_file('/etc/sysconfig/nfs').with({
        :content => /MOUNTD_PORT=20048/,
    #    :notify  => ['Service[rpcidmapd]', 'Service[nfs]']
      })
    }
  end

  describe "RHEL 7" do
    let(:facts) {base_facts['RHEL 7']}
    it { should create_file('/etc/sysconfig/nfs') }
  end
end
