# == Class: nfs
#
# Provides the base segments for NFS server *and* client services.
#
# == Parameters
#
# [*mountd_nfs_v1*]
#   Accepts: true|false
#   Default: true
#   Whether or not to act as an NFSv1 server. Due to current issues in
#   RHEL/CentOS this must be set to 'yes' to properly unmount.
#
# [*mountd_nfs_v2*]
#   Accepts: true|false
#   Default: false
#   Whether or not to act as an NFSv2 server.
#
# [*mountd_nfs_v3*]
#   Accepts: true|false
#   Default: false
#   Whether or not to act as an NFSv3 server.
#
# [*rquotad*]
#   Accepts: Fully Qualified Path
#   Default: '/usr/sbin/rpc/rquotad'
#   The path to the rquotad executable.
#
# [*rquotad_port*]
#   Accepts: Integer
#   Default: '875'
#   The port upon which rquotad should listen.
#
# [*lockd_tcpport*]
#   Accepts: Integer
#   Default: 32803
#   The TCP port upon which lockd should listen.
#
# [*lockd_udpport*]
#   Accepts: Integer
#   Default: 32803
#   The UDP port upon which lockd should listen.
#
# [*rpcnfsdargs*]
#   Accepts: String
#   Default: '-N 2'
#   Arbitrary arguments to pass to nfsd. The defaults disable NFSv2
#   from being served to clients.
#
# [*rpcnfsdcount*]
#   Accepts: Integer
#   Default: '8'
#   The number of NFS server threads to start by default.
#
# [*nfsd_v4_grace*]
#   Accepts: Integer
#   Default: 90
#   The V4 grace period in seconds.
#
# [*mountd_port*]
#   Accepts: Integer
#   Default: '892'
#   The port upon which mountd should listen.
#
# [*statd_port*]
#   Accepts: Integer
#   Default: '662'
#   The port upon which statd should listen.
#
# [*statd_outgoing_port*]
#   Accepts: Integer
#   Default: '2020'
#   The port that statd will use when connecting to client systems.
#
# [*secure_nfs*]
#   Accepts: true|false
#   Default: true
#   Enable secure NFS mounts.
#
# == Authors
#
# * Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
# * Kendall Moore <mailto:kmoore@keywcorp.com>
#
class nfs (
  $server,
  $use_stunnel = false,
  $is_server = false,
  $is_client = true,
  $nfsv3 = false,
  $mountd_nfs_v1 = true,
  $mountd_nfs_v2 = false,
  $mountd_nfs_v3 = false,
  $rquotad = '/usr/sbin/rpc.rquotad',
  $rquotad_port = '875',
  $lockd_tcpport = '32803',
  $lockd_udpport = '32769',
  $rpcnfsdargs = '-N 2',
  $rpcnfsdcount = '8',
  $nfsd_v4_grace = '90',
  $mountd_port = '20048',
  $statd_port = '662',
  $statd_outgoing_port = '2020',
  $secure_nfs = true
){

  include 'nfs::service_names'

  validate_absolute_path($rquotad)
  validate_bool($use_stunnel)
  validate_bool($is_server)
  validate_bool($is_client)
  validate_bool($nfsv3)
  validate_bool($mountd_nfs_v1)
  validate_bool($mountd_nfs_v2)
  validate_bool($mountd_nfs_v3)
  validate_bool($secure_nfs)
  validate_integer($rpcnfsdcount)
  validate_integer($nfsd_v4_grace)
  validate_port($rquotad_port)
  validate_port($lockd_tcpport)
  validate_port($lockd_udpport)
  validate_port($mountd_port)
  validate_port($statd_port)
  validate_port($statd_outgoing_port)

  if $use_stunnel {
    include 'stunnel'
  }

  if host_is_me($server) or $is_server {
    include 'nfs::server'

    file { '/etc/exports':
      ensure    => 'file',
      mode      => '0640',
      owner     => 'root',
      group     => 'root',
      content   => undef,
      source    => concat_output('nfs'),
      subscribe => Concat_build['nfs'],
      audit     => content,
      notify    => Exec['nfs_re-export']
    }
  }
  else {
    file { '/etc/exports':
      ensure  => 'file',
      mode    => '0640',
      owner   => 'root',
      group   => 'root',
      content => "\n"
    }
  }

  package { 'nfs-utils':
    ensure => 'latest'
  }

  package { 'nfs4-acl-tools':
    ensure => 'latest'
  }

  service { $::nfs::service_names::nfs_lock :
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
    hasstatus  => false,
    status     =>
      '/bin/true; source /etc/rc.d/init.d/functions; status rpc.statd',
    require    => [
      Service[$::nfs::service_names::rpcbind],
      Package['nfs-utils']
    ]
  }

  if ($is_client) and ($nfsv3) and ($use_stunnel) {
    service { $::nfs::service_names::rpcbind :
      ensure     => 'stopped',
      enable     => false,
      hasrestart => true,
      hasstatus  => true
    }
  }
  else {
    service { $::nfs::service_names::rpcbind :
      ensure     => 'running',
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
      require    => Service[$::nfs::service_names::rpcidmapd]
    }
  }

  svckill::ignore { 'nfs-idmap': }
  svckill::ignore { 'nfs-secure': }
  svckill::ignore { 'nfs-mountd': }
  svckill::ignore { 'nfs-rquotad': }

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
    require    => Package['nfs-utils']
  }

  $nfs_notifies = $is_server ? {
    true    => [
      Service[$::nfs::service_names::rpcidmapd],
      Service[$::nfs::service_names::nfs_server]
    ],
    default => Service[$::nfs::service_names::rpcgssd]
  }

  file { '/etc/sysconfig/nfs':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('nfs/nfs_sysconfig.erb'),
    notify  => $nfs_notifies
  }

  if $secure_nfs {
    service { $::nfs::service_names::rpcgssd :
      ensure     => 'running',
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
      require    => Service[$::nfs::service_names::rpcbind]
    }
  }

  if $is_client {
    include 'nfs::client'
  }
}
