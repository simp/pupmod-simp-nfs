require 'spec_helper'

describe 'nfs::idmapd' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts){ facts }

        let(:pre_condition) { 'class { "nfs": is_server => true }' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs::idmapd') }
        it { is_expected.to create_file('/etc/idmapd.conf').with({
            :content => /Domain\s=\s#{facts[:domain]}/
          })
        }
      end
    end
  end
end
