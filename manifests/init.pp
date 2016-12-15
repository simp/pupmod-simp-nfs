# Provides the base segments for NFS server *and* client services.
#
# @param stunnel If set, wrap stunnel around the NFS server
#   connections. This is ideally suited for environments without a working
#   Kerberos setup and may cause issues when used together.
#
# @param is_server Explicitly state that this system should be an NFS
#   server. Further configuration will need to be made via the `nfs::server`
#   classes.
#
# @param is_client Explicitly stat that this system should be an NFS
#   client. Further configuration will need to be made via the `nfs::client`
#   classes.
#
# @param nfsv3
#
# @param mountd_nfs_v1 Whether or not to act as an NFSv1 server. Due
#   to current issues in RHEL/CentOS this must be set to 'yes' to properly
#   unmount.
#
# @param mountd_nfs_v2 Whether or not to act as an NFSv2 server.
#
# @param mountd_nfs_v3 Whether or not to act as an NFSv3 server.
#
# @param rquotad The path to the rquotad executable.
#
# @param rquotad_port The port upon which rquotad should listen.
#
# @param lockd_tcpport The TCP port upon which lockd should listen.
#
# @param lockd_udpport The UDP port upon which lockd should listen.
#
# @param rpcnfsdargs Arbitrary arguments to pass to nfsd. The defaults
#   disable NFSv2 from being served to clients.
#
# @param rpcnfsdcount The number of NFS server threads to start by
#   default.
#
# @param nfsd_v4_grace The V4 grace period in seconds.
#
# @param mountd_port The port upon which mountd should listen.
#
# @param statd_port The port upon which statd should listen.
#
# @param statd_outgoing_port The port that statd will use when
#   connecting to client systems.
#
# @param secure_nfs Enable secure NFS mounts.
#
# @param ensure_lvm2_latest See nfs::lvm2 for further description.
#
# @param kerberos Use the SIMP `krb5` module for Kerberos support.
#   @note You may need to set variables in `::krb5::config` via Hiera or your
#     ENC if you do not like the defaults.
#
# @param simp_keytab_on_puppet If set, and $kerberos is true, then
#   set the NFS server to pull its keytab directly from the Puppet server.
#
# @param firewall If set, use the SIMP iptables module to manage
#   firewall connections.
#
# @param tcpwrappers If set, use the SIMP tcpwrappers module to
#   manage tcpwrappers.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
# @author Kendall Moore <kendall.moore@onyxpoint.com>
#
class nfs (
  Boolean                  $stunnel               = simplib::lookup('simp_options::stunnel', { 'default_value'     => false }),
  Boolean                  $is_server             = false,
  Boolean                  $is_client             = true,
  Boolean                  $nfsv3                 = false,
  Boolean                  $mountd_nfs_v1         = true,
  Boolean                  $mountd_nfs_v2         = false,
  Boolean                  $mountd_nfs_v3         = false,
  Stdlib::Absolutepath     $rquotad               = '/usr/sbin/rpc.rquotad',
  Stdlib::Compat::Integer  $rquotad_port          = '875',
  Stdlib::Compat::Integer  $lockd_tcpport         = '32803',
  Stdlib::Compat::Integer  $lockd_udpport         = '32769',
  String                   $rpcnfsdargs           = '-N 2',
  Stdlib::Compat::Integer  $rpcnfsdcount          = '8',
  Stdlib::Compat::Integer  $nfsd_v4_grace         = '90',
  Stdlib::Compat::Integer  $mountd_port           = '20048',
  Stdlib::Compat::Integer  $statd_port            = '662',
  Stdlib::Compat::Integer  $statd_outgoing_port   = '2020',
  Boolean                  $secure_nfs            = false,
  Boolean                  $ensure_lvm2_latest    = true,
  Boolean                  $kerberos              = simplib::lookup('simp_options::kerberos', { 'default_value'    => false }),
  Boolean                  $simp_keytab_on_puppet = true,
  Boolean                  $firewall              = simplib::lookup('simp_options::firewall', { 'default_value'    => false }),
  Boolean                  $tcpwrappers           = simplib::lookup('simp_options::tcpwrappers', { 'default_value' => false })
){

  include '::nfs::service_names'

  validate_port($rquotad_port)
  validate_port($lockd_tcpport)
  validate_port($lockd_udpport)
  validate_port($mountd_port)
  validate_port($statd_port)
  validate_port($statd_outgoing_port)

  include '::nfs::install'

  if $kerberos {
    include '::krb5'

    if $::operatingsystem in ['RedHat', 'CentOS'] {
      if (versioncmp($::operatingsystemmajrelease,'6') > 0) {
        # This is here because the SELinux rules for directory includes in krb5
        # are broken.

        include '::nfs::selinux_hotfix'

        Class['::nfs::selinux_hotfix'] -> Class['::nfs::install']
      }
    }

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

  if $is_server {

    include '::nfs::server'

    Class['nfs::install'] -> Class['nfs::server']

    if $kerberos {
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

      File['/etc/sysconfig/nfs'] -> Service[$::nfs::service_names::rpcgssd]
      Service[$::nfs::service_names::rpcbind] -> Service[$::nfs::service_names::rpcgssd]
    }
  }

  if $is_server or $nfsv3 {

    service { $::nfs::service_names::nfs_lock :
      ensure     => 'running',
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
      require    => File['/etc/sysconfig/nfs']
    }

    if (!$is_server and $is_client and $stunnel) {
      service { $::nfs::service_names::rpcbind :
        ensure  => 'stopped',
        require => File['/etc/sysconfig/nfs']
      }
    }
    else {
      service { $::nfs::service_names::rpcbind :
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true
      }

      File['/etc/sysconfig/nfs'] -> Service[$::nfs::service_names::rpcbind]
      Service[$::nfs::service_names::rpcbind] -> Service[$::nfs::service_names::nfs_lock]
    }
  }
  else {
    service { $::nfs::service_names::rpcbind :
      ensure  => 'stopped',
      require => Class['nfs::install']
    }
  }

  svckill::ignore { 'nfs-idmap': }
  svckill::ignore { 'nfs-secure': }
  svckill::ignore { 'nfs-mountd': }
  svckill::ignore { 'nfs-rquotad': }

  simpcat_build { 'sysconfig_nfs':
    quiet  => true,
    target => '/etc/sysconfig/nfs'
  }

  simpcat_fragment { 'sysconfig_nfs+init':
    content => template('nfs/nfs_sysconfig.erb')
  }

  file { '/etc/sysconfig/nfs':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Simpcat_build['sysconfig_nfs']
  }

  Class['nfs::install'] -> File['/etc/sysconfig/nfs']

  if $is_server {
    File['/etc/sysconfig/nfs'] ~> Service[$::nfs::service_names::nfs_server]
  }
}
