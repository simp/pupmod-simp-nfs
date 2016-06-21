# Provides the base segments for NFS server *and* client services.
#
# @param use_stunnel [Boolean] If set, wrap stunnel around the NFS server
#   connections. This is ideally suited for environments without a working
#   Kerberos setup. However, they can be used synchronously.
#
# @param is_server [Boolean] Explicitly state that this system should be an NFS
#   server. Further configuration will need to be made via the `nfs::server`
#   classes.
#
# @param is_client [Boolean] Explicitly stat that this system should be an NFS
#   client. Further configuration will need to be made via the `nfs::client`
#   classes.
#
# @param mountd_nfs_v1 [Boolean] Whether or not to act as an NFSv1 server. Due
#   to current issues in RHEL/CentOS this must be set to 'yes' to properly
#   unmount.
#
# @param mountd_nfs_v2 [Boolean] Whether or not to act as an NFSv2 server.
#
# @param mountd_nfs_v3 [Boolean] Whether or not to act as an NFSv3 server.
#
# @param rquotad [Absolute Path] The path to the rquotad executable.
#
# @param rquotad_port [Integer] The port upon which rquotad should listen.
#
# @param lockd_tcpport [Integer] The TCP port upon which lockd should listen.
#
# @param lockd_udpport [Integer] The UDP port upon which lockd should listen.
#
# @param rpcnfsdargs [String] Arbitrary arguments to pass to nfsd. The defaults
#   disable NFSv2 from being served to clients.
#
# @param rpcnfsdcount [Integer] The number of NFS server threads to start by
#   default.
#
# @param nfsd_v4_grace [Integer] The V4 grace period in seconds.
#
# @param mountd_port [Port] The port upon which mountd should listen.
#
# @param statd_port [Port] The port upon which statd should listen.
#
# @param statd_outgoing_port [Port] The port that statd will use when
#   connecting to client systems.
#
# @param secure_nfs [Boolean] Enable secure NFS mounts.
#
# @param ensure_lvm2_latest [Boolean] See nfs::lvm2 for further description.
#
# @param simp_krb5 [Boolean] Use the SIMP `krb5` module for Kerberos support.
#   @note You may need to set variables in `::krb5::config` via Hiera or your
#     ENC if you do not like the defaults.
#
# @param simp_keytab_on_puppet [Boolean] If set, and $simp_krb5 is true, then
#   set the NFS server to pull its keytab directly from the Puppet server.
#
# @param simp_iptables [Boolean] If set, use the SIMP iptables module to manage
#   firewall connections.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
# @author Kendall Moore <kendall.moore@onyxpoint.com>
#
class nfs (
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
  $secure_nfs = true,
  $ensure_lvm2_latest = true,
  $simp_krb5 = defined('$::simp_krb5') ? { true => getvar($::simp_krb5), default => hiera('simp_krb5', true) },
  $simp_keytab_on_puppet = true,
  $simp_iptables = defined('$::use_iptables') ? { true => getvar('::use_iptables'), default => hiera('use_iptables',true) }
){

  include '::nfs::service_names'

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
  validate_bool($ensure_lvm2_latest)
  validate_bool($simp_keytab_on_puppet)
  validate_bool($simp_krb5)

  $_is_server = ($is_server or (host_is_me($server) and $use_stunnel))

  include '::nfs::install'

  if $simp_krb5 {
    include '::krb5'

    if $simp_keytab_on_puppet {
      include '::krb5::keytab'
    }
  }

  if $ensure_lvm2_latest {
    include '::nfs::lvm2'

    Class['nfs::lvm2'] -> Class['nfs::install']
  }

  if $is_client {
    include '::nfs::client'

    Class['nfs::install'] -> Class['nfs::client']
  }

  if $_is_server {

    include '::nfs::server'

    Class['nfs::install'] -> Class['nfs::server']

    if $simp_krb5 {
      Class['krb5'] ~> Class['nfs::server']

      if $simp_keytab_on_puppet {
        Class['krb5::keytab'] ~> Class['nfs::server']
      }
    }
  }

  if $secure_nfs {
    if !empty($::nfs::service_names::rpcgssd) {
      service { $::nfs::service_names::rpcgssd :
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true
      }

      # If you don't put your keytabs on the Puppet server, you'll need to add
      # code to trigger this yourself!
      if $simp_keytab_on_puppet {
        Class['krb5::keytab'] ~> Service[$::nfs::service_names::rpcgssd]
      }

      Class['nfs::install'] -> Service[$::nfs::service_names::rpcgssd]
      Service[$::nfs::service_names::rpcbind] -> Service[$::nfs::service_names::rpcgssd]
    }
  }

  if $_is_server or $nfsv3 {

    service { $::nfs::service_names::nfs_lock :
      ensure     => 'running',
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
      require    => [
        Class['nfs::install'],
        Package['nfs-utils']
      ]
    }

    if (!$_is_server and $is_client and $use_stunnel) {
      service { $::nfs::service_names::rpcbind :
        ensure  => 'stopped',
        enable  => false,
        require => Class['nfs::install']
      }
    }
    else {
      service { $::nfs::service_names::rpcbind :
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true
      }

      Class['nfs::install'] -> Service[$::nfs::service_names::rpcbind]
      Service[$::nfs::service_names::rpcbind] -> Service[$::nfs::service_names::nfs_lock]
    }
  }
  else {
    service { $::nfs::service_names::rpcbind :
      ensure => 'stopped',
      enable => false,
      require => Class['nfs::install']
    }
  }

  svckill::ignore { 'nfs-idmap': }
  svckill::ignore { 'nfs-secure': }
  svckill::ignore { 'nfs-mountd': }
  svckill::ignore { 'nfs-rquotad': }

  file { '/etc/sysconfig/nfs':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('nfs/nfs_sysconfig.erb')
  }

  Class['nfs::install'] -> File['/etc/sysconfig/nfs']

  if $_is_server {
    File['/etc/sysconfig/nfs'] ~> Service[$::nfs::service_names::nfs_server]
  }
}
