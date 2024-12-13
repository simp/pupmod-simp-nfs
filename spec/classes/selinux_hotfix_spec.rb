require 'spec_helper'

describe 'nfs::selinux_hotfix' do
  def mock_selinux_false_facts(os_facts)
    os_facts[:selinux] = false
    os_facts[:os][:selinux][:config_mode] = 'disabled'
    os_facts[:os][:selinux][:current_mode] = 'disabled'
    os_facts[:os][:selinux][:enabled] = false
    os_facts[:os][:selinux][:enforced] = false
    os_facts
  end

  def mock_selinux_enforcing_facts(os_facts)
    os_facts[:selinux] = true
    os_facts[:os][:selinux][:config_mode] = 'enforcing'
    os_facts[:os][:selinux][:config_policy] = 'targeted'
    os_facts[:os][:selinux][:current_mode] = 'enforcing'
    os_facts[:os][:selinux][:enabled] = true
    os_facts[:os][:selinux][:enforced] = true
    os_facts
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      before(:each) do
        # Mask 'assert_private' for testing
        Puppet::Parser::Functions.newfunction(:assert_private, type: :rvalue) { |args| }
      end

      context 'selinux_current_mode fact not present' do
        let(:facts) do
          os_facts = mock_selinux_false_facts(os_facts)
          os_facts.delete(:selinux_current_mode)
          os_facts
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_vox_selinux__module('gss_hotfix') }
      end

      context 'selinux_current_mode = disabled' do
        let(:facts) { mock_selinux_false_facts(os_facts) }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_vox_selinux__module('gss_hotfix') }
      end

      context 'selinux_current_mode != disabled' do
        let(:facts) { mock_selinux_enforcing_facts(os_facts) }

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_vox_selinux__module('gss_hotfix').with({
                                                                          ensure: 'present',
          builder: 'simple',
          content_te: <<~EOM
            module gss_hotfix 1.0;

            require {
            \ttype gssd_t;
            \ttype gssproxy_t;
            \ttype krb5_conf_t;
            \tclass dir { read search open };
            }

            #============= gssd_t ==============
            allow gssd_t krb5_conf_t:dir search;
            allow gssd_t krb5_conf_t:dir { read open };

            #============= gssproxy_t ==============
            allow gssproxy_t krb5_conf_t:dir search;
            allow gssproxy_t krb5_conf_t:dir { read open };
            EOM
                                                                        })
        }
      end
    end
  end
end
