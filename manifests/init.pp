# Provides the base segments for NFS server *and* client services.
#
# @param is_server
#   Explicitly state that this system should be an NFS server
#
#   * Further configuration will need to be made via the ``nfs::server``
#     classes
#
# @param is_client
#   Explicitly state that this system should be an NFS client
#
#   * Further configuration will need to be made via the ```nfs::client``
#     classes
#
# @param nfsv3
#   Use NFSv3 for connections
#
# @param mountd_nfs_v1
#   Act as an ``NFSv1`` server
#
#   * Due to current issues in RHEL/CentOS this must be set to ``yes`` to
#     properly unmount
#
# @param mountd_nfs_v2
#   Act as an ``NFSv2`` server
#
# @param mountd_nfs_v3
#   Act as an ``NFSv3`` server
#
# @param rquotad
#   The path to the ``rquotad`` executable
#
# @param rquotad_port
#   The port upon which ``rquotad`` should listen
#
# @param lockd_tcpport
#   The TCP port upon which ``lockd`` should listen
#
# @param lockd_udpport
#   The UDP port upon which ``lockd`` should listen
#
# @param rpcnfsdargs
#   Arbitrary arguments to pass to ``nfsd``
#
#   * The defaults disable ``NFSv2`` from being served to clients
#
# @param rpcnfsdcount
#   The number of NFS server threads to start by default
#
# @param nfsd_v4_grace
#   The NFSv4 grace period, in seconds
#
# @param mountd_port
#   The port upon which ``mountd`` should listen
#
# @param statd_port
#   The port upon which ``statd`` should listen
#
# @param statd_outgoing_port
#   The port that ``statd`` will use when connecting to client systems
#
# @param secure_nfs
#   Enable secure NFS mounts
#
# @param ensure_latest_lvm2
#   See ``nfs::lvm2`` for further description
#
# @param kerberos
#   Use the SIMP ``krb5`` module for Kerberos support
#
#   * You may need to set variables in ``::krb5::config`` via Hiera or your ENC
#     if you do not like the defaults.
#
# @param keytab_on_puppet
#   If set, and ``$krb5`` is ``true`` then set the NFS server to pull its
#   keytab directly from the Puppet server
#
# @param firewall
#   Use the SIMP ``iptables`` module to manage firewall connections
#
# @param tcpwrappers
#   Use the SIMP ``tcpwrappers`` module to manage tcpwrappers
#
# @param stunnel
#   Wrap ``stunnel`` around the NFS server connections
#
#   * This is ideally suited for environments without a working Kerberos setup
#     and may cause issues when used together
#
# @param stunnel_tcp_nodelay
#   Enable TCP_NODELAY for all stunnel connections
#
# @param stunnel_socket_options
#   Additional socket options to set for stunnel connections
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
# @author Kendall Moore <kendall.moore@onyxpoint.com>
#
class nfs (
  Boolean              $is_server              = false,
  Boolean              $is_client              = true,
  Boolean              $nfsv3                  = false,
  Boolean              $mountd_nfs_v1          = true,
  Boolean              $mountd_nfs_v2          = false,
  Boolean              $mountd_nfs_v3          = false,
  Stdlib::Absolutepath $rquotad                = '/usr/sbin/rpc.rquotad',
  Simplib::Port        $rquotad_port           = 875,
  Simplib::Port        $lockd_tcpport          = 32803,
  Simplib::Port        $lockd_udpport          = 32769,
  String               $rpcnfsdargs            = '-N 2',
  Integer[0]           $rpcnfsdcount           = 8,
  Integer[0]           $nfsd_v4_grace          = 90,
  Simplib::Port        $mountd_port            = 20048,
  Simplib::Port        $statd_port             = 662,
  Simplib::Port        $statd_outgoing_port    = 2020,
  Boolean              $secure_nfs             = false,
  Boolean              $ensure_latest_lvm2     = true,
  Boolean              $kerberos               = simplib::lookup('simp_options::kerberos', { 'default_value' => false }),
  Boolean              $keytab_on_puppet       = simplib::lookup('simp_options::kerberos', { 'default_value' => true}),
  Boolean              $firewall               = simplib::lookup('simp_options::firewall', { 'default_value' => false}),
  Boolean              $tcpwrappers            = simplib::lookup('simp_options::tcpwrappers', { 'default_value' => false }),
  Boolean              $stunnel                = simplib::lookup('simp_options::stunnel', { 'default_value' => false }),
  Boolean              $stunnel_tcp_nodelay    = true,
  Array[String]        $stunnel_socket_options = []
){

  simplib::assert_metadata($module_name)

  if $stunnel_tcp_nodelay {
    $_stunnel_socket_options = $stunnel_socket_options + [
      'l:TCP_NODELAY=1',
      'r:TCP_NODELAY=1'
    ]
  }
  else {
    $_stunnel_socket_options = $stunnel_socket_options
  }

  include '::nfs::service_names'
  include '::nfs::install'

  if $kerberos {
    include '::krb5'

    if ($::operatingsystem in ['RedHat', 'CentOS', 'OracleLinux']) {
      if (versioncmp($::operatingsystemmajrelease,'6') > 0) {
        # This is here because the SELinux rules for directory includes in krb5
        # are broken.

        include '::nfs::selinux_hotfix'

        Class['::nfs::selinux_hotfix'] -> Class['::nfs::install']
      }
    }

    if $keytab_on_puppet {
      include '::krb5::keytab'
    }
  }

  if $ensure_latest_lvm2 {
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

      if $keytab_on_puppet {
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
      if $keytab_on_puppet {
        Class['krb5::keytab'] ~> Service[$::nfs::service_names::rpcgssd]
      }

      Concat['/etc/sysconfig/nfs'] -> Service[$::nfs::service_names::rpcgssd]
      Service[$::nfs::service_names::rpcbind] -> Service[$::nfs::service_names::rpcgssd]
    }
  }

  if $is_server or $nfsv3 {

    service { $::nfs::service_names::nfs_lock :
      ensure     => 'running',
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
      require    => Concat['/etc/sysconfig/nfs']
    }

    if (!$is_server and $is_client and $stunnel) {
      service { $::nfs::service_names::rpcbind :
        ensure  => 'stopped',
        require => Concat['/etc/sysconfig/nfs']
      }
    }
    else {
      service { $::nfs::service_names::rpcbind :
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true
      }

      Concat['/etc/sysconfig/nfs'] -> Service[$::nfs::service_names::rpcbind]
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

  concat { '/etc/sysconfig/nfs':
    owner          => 'root',
    group          => 'root',
    mode           => '0644',
    ensure_newline => true,
    warn           => true
  }

  concat::fragment { 'nfs_init':
    order   => 5,
    target  => '/etc/sysconfig/nfs',
    content => template("${module_name}/etc/sysconfig/nfs.erb")
  }

  Class['nfs::install'] -> Concat['/etc/sysconfig/nfs']

  if $is_server {
    Concat['/etc/sysconfig/nfs'] ~> Service[$::nfs::service_names::nfs_server]
  }
}
