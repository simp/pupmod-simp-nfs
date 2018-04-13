require 'spec_helper'

describe 'nfs::client::stunnel' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      let(:params) {{
        :nfs_server => '1.2.3.4'
      }}

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('nfs::client::stunnel') }
      it { is_expected.to create_stunnel__instance('nfs_client').with_systemd_wantedby(['remote-fs-pre.target']) }
      if facts[:os][:release][:major] == '7'
        it { is_expected.to create_file('/etc/systemd/system/stunnel_managed_by_puppet_nfs_client.service') \
          .with_content(/WantedBy=remote-fs-pre.target/)
        }
      end
    end
  end
end
