require 'spec_helper'

describe 'nfs::server::create_home_dirs' do

  let(:facts) {{
    :ldapuri      => 'ldap:://test.example.domain',
    :basedn       => 'dc=example,dc=domain',
    :ldap_bind_dn => 'cn=hostAuth,ou=Hosts,dc=example,dc=domain',
    :ldap_bind_pw => 'OJKShsdf89324jkSA*&(*AEWjh21A87A^d',
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

  it { should create_class('nfs::server::create_home_dirs') }
  it { should create_file('/etc/cron.hourly/create_home_directories.rb') }
end
