# Adds a script to create user home directories for directory server by pulling
# users from LDAP
#
# @param uri [Array] The Array of LDAP URIs.
#
# @param user_ou [String] The OU under which users are stored.
#
# @param export_dir [Absolute Path] The location of the home directories being
#   exported.  This location will have to have a puppet managed File resource
#   associated.  See the `nfs::stock::export_home` class for an example
#
# @param skel_dir [Absolute Path] The location of sample skeleton files for
#   user directories. By default this is /etc/skel which is not managed by
#   Puppet, therefore, no required File resource here
#
# @param ldap_scope [String] The search scope to use.
#   Valid Options: 'one', 'sub', 'base'

#   @note Defaults to 'base' if an invalid option is specified.
#
# @param bind_dn [String] The DN to use when binding to the LDAP server
#
# @param bind_pw [String] The password to use when binding to the LDAP server
#
# @param port [Port] The target port on the LDAP server
#
# @param tls [Boolean] Whether or not to enable TLS for the connection.
#   * $tls = false -> No Encryption
#   * $tls = 'ssl' -> SSL (ldaps support)
#   * $tls = anything else -> STARTTLS (default)
#
# @param quiet [Boolean] Whether or not to print potentially useful warnings
#
# @param syslog_facility [String] The syslog facility at which to log, must be
#   Ruby `syslog` compatible.
#
# @param syslog_priority [String] The syslog priority at which to log, must be
#   Ruby `syslog` compatible.
#
# @author Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
#
class nfs::server::create_home_dirs (
  $uri = defined('$::ldap::uri') ? { true => getvar('::ldap::uri'), default => hiera('ldap::uri') },
  $base_dn = defined('$::ldap::base_dn') ? { true => getvar('::ldap::base_dn'), default => hiera('ldap::base_dn') },
  $export_dir = versioncmp(simp_version(),'5') ? { '-1' => '/srv/nfs/home', default => '/var/nfs/home' },
  $skel_dir = '/etc/skel',
  $ldap_scope = 'one',
  $bind_dn = defined('$::ldap::bind_dn') ? { true => getvar('::ldap::bind_dn'), default => hiera('ldap::bind_dn') },
  $bind_pw = defined('$::ldap::bind_pw') ? { true => getvar('::ldap::bind_pw'), default => hiera('ldap::bind_pw') },
  $port = '389',
  $tls = true,
  $quiet = true,
  $syslog_facility = 'LOG_LOCAL6',
  $syslog_priority = 'LOG_NOTICE',
) {

  validate_array($uri)
  validate_string($base_dn)
  validate_absolute_path($export_dir)
  validate_absolute_path($skel_dir)
  validate_array_member($ldap_scope, ['one','sub','base'])
  validate_string($bind_dn)
  validate_string($bind_pw)
  validate_port($port)
  validate_bool($tls)
  validate_bool($quiet)
  validate_string($syslog_facility)
  validate_string($syslog_priority)

  file { '/etc/cron.hourly/create_home_directories.rb':
    owner   => 'root',
    group   => 'root',
    mode    => '0500',
    content => template('nfs/create_home_directories.rb.erb'),
    notify  => Exec['/etc/cron.hourly/create_home_directories.rb'],
    require => [
      Package['ruby-ldap'],
      File[$export_dir]
    ]
  }

  exec { '/etc/cron.hourly/create_home_directories.rb': refreshonly => true }
}
