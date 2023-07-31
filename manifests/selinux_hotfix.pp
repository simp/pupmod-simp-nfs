# @summary Provides hotfix for broken SElinux policy
#
# This class provides a hotfix for a broken SELinux policy in EL7,
# selinux-policy < 3.13.1-229.el7_6.9.
#
# The OS confinement of this class should be done elsewhere
#
# @api private
#
class nfs::selinux_hotfix {
  assert_private()

  if $facts['os']['selinux']['current_mode'] and $facts['os']['selinux']['current_mode'] != 'disabled' {
    vox_selinux::module { 'gss_hotfix':
      ensure     => 'present',
      content_te => file("${module_name}/selinux/gss_hotfix.te"),
      builder    => 'simple'
    }
  }
}
