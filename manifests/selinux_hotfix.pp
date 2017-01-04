# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# This class provides a hotfix for a broken SELinux policy in EL7
#
# The OS confinement of this class should be done elsewhere
#
class nfs::selinux_hotfix {
  assert_private()

  if $facts['selinux_current_mode'] and $facts['selinux_current_mode'] != 'disabled' {
    $hotfix_dir = '/usr/share/selinux/simp_hotfix'

    ensure_resource('file', $hotfix_dir, {
        'ensure' => 'directory',
        'mode'   => '0644'
      }
    )

    ensure_resource('package', ['checkpolicy', 'policycoreutils-python'])

    Package['checkpolicy'] -> File["${hotfix_dir}/gss"]
    Package['policycoreutils-python'] -> File["${hotfix_dir}/gss"]

    file { "${hotfix_dir}/gss":
      ensure => 'directory',
      owner  => 'root',
      group  => 'root',
      mode   => '0600'
    }

    file { "${hotfix_dir}/gss/gss_hotfix.te":
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => file("${module_name}/selinux/gss_hotfix.te")
    }

    exec { 'gss_selinux_hotfix_build_module':
      command => '/bin/checkmodule -M -m -o gss_hotfix.mod gss_hotfix.te',
      cwd     => "${hotfix_dir}/gss",
      unless  => '/sbin/semodule -l | /bin/grep -q gss_hotfix',
      require => File["${hotfix_dir}/gss/gss_hotfix.te"],
      notify  => Exec['gss_selinux_hotfix_package_module']
    }

    exec { 'gss_selinux_hotfix_package_module':
      command     => '/usr/bin/semodule_package -o gss_hotfix.pp -m gss_hotfix.mod',
      cwd         => "${hotfix_dir}/gss",
      refreshonly => true,
      notify      => Exec['gss_selinux_hotfix_install_module']
    }

    exec { 'gss_selinux_hotfix_install_module':
      command     => '/usr/sbin/semodule -i gss_hotfix.pp',
      cwd         => "${hotfix_dir}/gss",
      refreshonly => true
    }
  }
}
