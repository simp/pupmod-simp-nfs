require 'spec_helper'

describe 'nfs::idmapd' do
  on_supported_os.each do |os, facts|
    before(:each) do
      Puppet::Parser::Functions.newfunction('assert_private') do |f|
        f.stubs(:call).returns(true)
      end
    end

    context "on #{os}" do
      let(:facts){ facts }

      let(:pre_condition) { 'class { "nfs": is_server => true }' }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs::idmapd') }
        it { is_expected.to create_file('/etc/idmapd.conf').with_content( <<EOM
# This file is managed by Puppet. Any changes made to the file will be
# overwritten at the next Puppet run.
[General]


[Mapping]

Nobody-User = nobody
Nobody-Group = nobody

[Translation]

Method = nsswitch

[Static]

[UMICH_SCHEMA]

# This is not yet supported by the SIMP configuration.
EOM
        )}
      end

      context 'with optional parameters set' do
        let(:params) {{
          :verbosity          => 2,
          :local_realms       => ['realm1', 'realm2'],
          :gss_methods        => ['nsswitch'],
          :static_translation => { 'key1' => 'value1', 'key2' => 'value2' }
        }}
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs::idmapd') }
        it { is_expected.to create_file('/etc/idmapd.conf').with_content( <<EOM
# This file is managed by Puppet. Any changes made to the file will be
# overwritten at the next Puppet run.
[General]

Verbosity = 2
Local-Realms = realm1,realm2

[Mapping]

Nobody-User = nobody
Nobody-Group = nobody

[Translation]

Method = nsswitch
GSS-Methods = nsswitch

[Static]
key1 = value1
key2 = value2

[UMICH_SCHEMA]

# This is not yet supported by the SIMP configuration.
EOM
        )}
      end
    end
  end
end
