require 'spec_helper'

describe 'nfs::idmapd::config' do
  context 'with default parameters' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('nfs::idmapd::config') }
    it {
      is_expected.to create_file('/etc/idmapd.conf').with_content(
      <<~EOM,
        # This file is managed by Puppet (simp-nfs module). Changes will be overwritten
        # at the next Puppet run.
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
    )
    }
  end

  context 'with optional parameters set and multiple methods' do
    let(:params) do
      {
        verbosity: 2,
        domain: 'mydomain',
        no_strip: 'both',
        reformat_group: false,
        local_realms: ['realm1', 'realm2'],
        trans_method: ['nsswitch', 'static'],
        gss_methods: ['nsswitch', 'static'],
        static_translation: { 'key1' => 'value1', 'key2' => 'value2' },
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('nfs::idmapd::config') }
    it {
      is_expected.to create_file('/etc/idmapd.conf').with_content(<<~EOM)
        # This file is managed by Puppet (simp-nfs module). Changes will be overwritten
        # at the next Puppet run.
        [General]

        Verbosity = 2
        Domain = mydomain
        No-Strip = both
        Reformat-Group = false
        Local-Realms = realm1,realm2

        [Mapping]

        Nobody-User = nobody
        Nobody-Group = nobody

        [Translation]

        Method = nsswitch,static
        GSS-Methods = nsswitch,static

        [Static]
        key1 = value1
        key2 = value2

        [UMICH_SCHEMA]

        # This is not yet supported by the SIMP configuration.
      EOM
    }
  end
end
