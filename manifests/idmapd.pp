# == Class: nfs::idmapd
#
# Provides for the configuration of idmapd
# The daemon is started from init.pp but you may need to tweak some values here
# for your environment.
#
# This is recommended for NFSv4 but not required for NFSv3. In RHEL5, the
# default values suffice in most cases but in RHEL6 the defaults for 'domain'
# may not work properly.
#
# All variable documentation can be found in idmapd.conf(5). Any deviations are
# documented below.
#
# == Parameters
#
# [*verbosity*]
# [*domain*]
# [*local_realms*]
#   Accepts either a comma separated string, or an array.
#
# [*nobody_user*]
# [*nobody_group*]
# [*trans_method*]
#   [Translation] Method. Method is a reserved word in Ruby.
#   umich_ldap is not supported at this time.
#
# [*gss_methods*]
#   Accepts either a comma separated string, or an array.
#
# [*static_translation*]
#   This is a hash that will be translated into the [Static] section
#   variables as presented in the man page.
#
#   For example: { 'foo' => 'bar' } will be foo = bar in the output file.
#
# == Authors
#
# * Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
#
class nfs::idmapd (
  $verbosity = '',
  $domain = $::domain,
  $local_realms = '',
  $nobody_user = 'nobody',
  $nobody_group = 'nobody',
  $trans_method = 'nsswitch',
  $gss_methods = '',
  $static_translation = ''
) {
  include '::nfs'

  file { '/etc/idmapd.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('nfs/idmapd.conf.erb'),
    notify  => Service[$::nfs::service_names::rpcidmapd]
  }
}
