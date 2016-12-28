# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# Provides for the configuration of ``idmapd``
#
# The daemon is started from ``init.pp`` but you may need to tweak some values
# here for your environment.
#
# This is recommended for ``NFSv4`` but not required for ``NFSv3``
#
# @see idmapd.conf(5)
#
# @param verbosity
# @param domain
# @param local_realms
# @param nobody_user
# @param nobody_group
# @param trans_method
#   ``[Translation]`` Method
#
#   * ``Method`` is a reserved word in Ruby
#   * ``umich_ldap`` is not yet supported
#
# @param gss_methods
# @param static_translation
#   Will be translated into the ``[Static]`` section variables as presented in
#   the man page
#
#   * For example: ``{ 'foo' => 'bar' }`` will be ``foo = bar`` in the output file
#
# @param content
#   Use this as the explicit content for the ``idmapd`` configuration file
#
#   * Overrides **all** other options
#
# @author Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
#
class nfs::idmapd (
  Optional[Integer]                          $verbosity          = undef,
  Optional[String]                           $domain             = undef,
  Optional[Array[String]]                    $local_realms       = undef,
  String                                     $nobody_user        = 'nobody',
  String                                     $nobody_group       = 'nobody',
  Array[Enum['nsswitch','static']]           $trans_method       = ['nsswitch'],
  Optional[Array[Enum['nsswitch','static']]] $gss_methods        = undef,
  Optional[Hash[String,String]]              $static_translation = undef,
  Optional[String]                           $content            = undef
) {
  assert_private()

  file { '/etc/idmapd.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template("${module_name}/idmapd.conf.erb"),
    notify  => Service[$::nfs::service_names::rpcidmapd]
  }

  $_startcmd = 'systemd' in $facts['init_systems'] ? {
    true    => "/usr/sbin/systemctl start ${::nfs::service_names::rpcidmapd}",
    default => "/usr/sbin/service ${::nfs::service_names::rpcidmapd} start"
  }

  service { $::nfs::service_names::rpcidmapd :
    ensure     => 'running',
    enable     => true,
    hasrestart => false,
    hasstatus  => true,
    start      => "${_startcmd}
      if [ \$? -ne 0 ]; then
        /bin/mount | /bin/grep -q 'sunrpc';
        if [ \$? -ne 0 ]; then
          /bin/mount -t rpc_pipefs sunrpc /var/lib/nfs/rpc_pipefs;
        fi
      fi
      ${_startcmd}",
    require    => Package['nfs-utils'],
    subscribe  => Concat['/etc/sysconfig/nfs']
  }
}
