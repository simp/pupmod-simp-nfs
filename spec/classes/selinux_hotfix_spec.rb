require 'spec_helper'

describe 'nfs::selinux_hotfix' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts){ os_facts }

      before(:each) do
        # Mask 'assert_private' for testing
        Puppet::Parser::Functions.newfunction(:assert_private, :type => :rvalue) { |args| }
      end

      context 'selinux_current_mode fact not present' do
        let(:facts) {
          new_facts = os_facts.dup
          new_facts.delete(:selinux_current_mode)
          new_facts
        }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to_not contain_vox_selinux__module('gss_hotfix') }
      end

      context 'selinux_current_mode = disabled' do
        let(:facts) { os_facts.merge({ :selinux_current_mode => 'disabled' }) }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to_not contain_vox_selinux__module('gss_hotfix') }
      end

      context 'selinux_current_mode != disabled' do
        let(:facts) { os_facts.merge({ :selinux_current_mode => 'enforcing' }) }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_vox_selinux__module('gss_hotfix').with( {
          :ensure     => 'present',
          :builder    => 'simple',
          :content_te => <<~EOM
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
        } ) }
      end
    end
  end
end
