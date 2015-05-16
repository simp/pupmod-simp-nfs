require 'spec_helper'

describe 'nfs::client::stunnel' do
  let(:facts) {{
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
  }}

  it { should create_class('nfs::client::stunnel') }

  context 'base' do
    it { should compile.with_all_deps }
    it { should create_stunnel__add('nfs_client') }
  end
end
