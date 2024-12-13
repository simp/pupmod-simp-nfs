require 'spec_helper'

describe 'nfs::idmapd::client' do
  context 'with default parameters' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('nfs::idmapd::client') }
    it { is_expected.to create_class('nfs::idmapd::config') }
    it do
      is_expected.to create_exec('enable_nfsidmap_request_key').with({
                                                                       unless: "/usr/bin/grep -v '#' /etc/request-key.conf | grep -q 'nfsidmap -t 600'",
        command: "/usr/bin/sed -r -i '/^create[[:space:]]+id_resolver[[:space:]]/d' /etc/request-key.conf;/usr/bin/sed -i '/^negate/i create\tid_resolver\t*\t*\t\t/usr/sbin/nfsidmap -t 600 %k %d' /etc/request-key.conf"
                                                                     })
    end
  end
end
