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
  Variant[Enum[''],Stdlib::Compat::Integer]  $verbosity          = '',
  String                                     $domain             = $::domain,
  Variant[String, Array[String]]             $local_realms       = '',
  String                                     $nobody_user        = 'nobody',
  String                                     $nobody_group       = 'nobody',
  String                                     $trans_method       = 'nsswitch',
  Variant[String, Array[String]]             $gss_methods        = '',
  Variant[Enum[''],Hash]                     $static_translation = ''
) {

  file { '/etc/idmapd.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('nfs/idmapd.conf.erb'),
    notify  => Service[$::nfs::service_names::rpcidmapd]
  }

  service { $::nfs::service_names::rpcidmapd :
    ensure     => 'running',
    enable     => true,
    hasrestart => false,
    hasstatus  => true,
    start      => "/sbin/service ${::nfs::service_names::rpcidmapd} start;
      if [ \$? -ne 0 ]; then
        /bin/mount | /bin/grep -q 'sunrpc';
        if [ \$? -ne 0 ]; then
          /bin/mount -t rpc_pipefs sunrpc /var/lib/nfs/rpc_pipefs;
        fi
      fi
      /sbin/service ${::nfs::service_names::rpcidmapd} start;",
    require    => Package['nfs-utils'],
    subscribe  => File['/etc/sysconfig/nfs']
  }
}
