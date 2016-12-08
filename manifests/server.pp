# Configure a NFS server with a default configuration that nails up the ports
# so that you can pass them through iptables.
#
# This defaults to NFSv4.
#
# @param trusted_nets [Net List] The systems that are allowed to connect to this
#   service, as an array. Set to 'any' or 'ALL' to allow the world.
#
# @param nfsv3 [Boolean] If set, this server serves out NFSv3 shares.
#
# @param rpcrquotadopts [String] Options that should be passed to rquotad at
#   start time.
#
# @param lockd_arg [String] Arbitrary options that should be passed to lockd.
#
# @param nfsd_module [String] If set to 'noload' will prevent the nfsd module
#   from being pre-loaded.
#   Valid Options: 'noload'
# NOTE: if this is set to _anything_ other than an empty string, the template
# will say 'noload'
#
# @param rpcmountdopts [String] An arbitrary string of options to pass to
#   mountd.
#
# @param statdarg [String] An arbitrary string of options to pass to statd.
#
# @param statd_ha_callout [AbsolutePath] The fully path of an application that
#   should be used for statd HA.
#
# @param rpcidmapdargs [String] Artibrary arguments to pass to idmapd.
#
# @param rpcgssdargs [String] Arbitrary arguments to pass to gssd.
#
# @param rpcsvcgssdargs [String] Arbitrary arguments to pass to svcgssd.
#
# @param sunrpc_udp_slot_table_entries [Integer] Raise the default udp slot
#   table entries in the kernel.  Most NFS server performance guides seem to
#   recommend this setting.  If you have a low memory system, you may want to
#   reduce this.
#
# @param sunrpc_tcp_slot_table_entries [Integer] Raise the default tcp slot
#   table entries in the kernel.  Most NFS server performance guides seem to
#   recommend this setting.  If you have a low memory system, you may want to
#   reduce this.
#
# @note Due to some bug in Red Hat, $mountd_nfs_v1 must be set to 'yes' to
#   properly unmount.
#
# @note The rpcbind port and the rpc.quotad ports are open to the client
#   networks so that the 'quota' command works on the clients.
#
# @param firewall [Boolean] If set, use the SIMP iptables module to manage
#   firewall connections.
#
# @param stunnel [Boolean] If set, use the SIMP stunnel module to manage
#   stunnel.
#
# @param tcpwrappers [Boolean] If set, use the SIMP tcpwrappers module to
#   manage tcpwrappers.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
# @author Morgan Rhodes <morgan@puppet.com>
# @author Kendall Moore <kendall.moore@onyxpoint.com>
#
class nfs::server (
  Array[String]                           $trusted_nets,
  Boolean                                 $nfsv3                         = $::nfs::nfsv3,
  String                                  $rpcrquotadopts                = '',
  String                                  $lockd_arg                     = '',
  String                                  $nfsd_module                   = '',
  String                                  $rpcmountdopts                 = '',
  String                                  $statdarg                      = '',
  Variant[Enum[''],Stdlib::Absolutepath]  $statd_ha_callout              = '',
  String                                  $rpcidmapdargs                 = '',
  String                                  $rpcgssdargs                   = '',
  String                                  $rpcsvcgssdargs                = '',
  Stdlib::Compat::Integer                 $sunrpc_udp_slot_table_entries = '128',
  Stdlib::Compat::Integer                 $sunrpc_tcp_slot_table_entries = '128',
  Boolean                                 $firewall                      = $::nfs::firewall,
  Boolean                                 $stunnel                       = $nfs::stunnel,
  Boolean                                 $tcpwrappers                   = $nfs::tcpwrappers
) inherits ::nfs {

  validate_net_list($trusted_nets)

  if $tcpwrappers {
    include '::tcpwrappers'
  }

  if $stunnel {
    include '::nfs::server::stunnel'

    # This is here due to some bug where allowing things through regularly
    # isn't working correctly.
    if $tcpwrappers {
      tcpwrappers::allow { 'nfs': pattern => 'ALL' }
    }
  }

  if $nfsv3 { include '::nfs::idmapd' }

  simpcat_fragment { 'sysconfig_nfs+server':
    content => template('nfs/nfs_sysconfig_server.erb')
  }

  simpcat_build { 'nfs':
    order  => '*.export',
    quiet  => true,
    target => '/etc/exports'
  }

  file { '/etc/exports':
    ensure => 'file',
    mode   => '0644',
    owner  => 'root',
    group  => 'root'
  }

  exec { 'nfs_re-export':
    command     => '/usr/sbin/exportfs -ra',
    refreshonly => true,
    require     => Package['nfs-utils']
  }

  Simpcat_build['nfs'] -> File['/etc/exports']
  File['/etc/exports'] ~> Exec['nfs_re-export']
  Simpcat_build['nfs'] ~> Exec['nfs_re-export']

  service { $::nfs::service_names::nfs_server :
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
    hasstatus  => true
  }

  Service[$::nfs::service_names::rpcbind] -> Service[$::nfs::service_names::nfs_server]

  # Plopping this in place so that NFS starts with the proper number of slot
  # entries upon reboot.
  file { '/etc/init.d/sunrpc_tuning':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0754',
    content => template('nfs/sunrpc_tuning.erb')
  }

  # $stunnel_port_override is a value that is set by the stunnel overlay.
  if $stunnel and $::nfs::server::stunnel::stunnel_port_override {
    if $firewall {
      include '::iptables'

      iptables::add_tcp_stateful_listen { 'nfs_client_tcp_ports':
        trusted_nets => $trusted_nets,
        dports       => $::nfs::server::stunnel::stunnel_port_override
      }
      iptables::add_udp_listen { 'nfs_client_udp_ports':
        trusted_nets => $trusted_nets,
        dports       => $::nfs::server::stunnel::stunnel_port_override
      }
    }
  }
  else {
    if ( $::nfs::mountd_nfs_v2 ) or ( $::nfs::mountd_nfs_v3 ) {
      $lports = [
        '111',
        '2049',
        $::nfs::rquotad_port,
        $::nfs::lockd_tcpport,
        $::nfs::mountd_port,
        $::nfs::statd_port
      ] # <-- End ports
    }
    else {
      $lports = [
        '111',
        '2049',
        $::nfs::rquotad_port
      ]
    }

    if $firewall {
      include '::iptables'
      iptables::add_tcp_stateful_listen { 'nfs_client_tcp_ports':
        trusted_nets => $trusted_nets,
        dports       => $lports
      }
      iptables::add_udp_listen { 'nfs_client_udp_ports':
        trusted_nets => $trusted_nets,
        dports       => $lports
      }
    }
  }

  service { 'sunrpc_tuning':
    enable  => true,
    require => File['/etc/init.d/sunrpc_tuning']
  }

  if $tcpwrappers {
    tcpwrappers::allow { [
      'mountd',
      'statd',
      'rquotad',
      'lockd',
      'rpcbind'
      ]:
      pattern => $trusted_nets
    }
  }


  sysctl { 'sunrpc.tcp_slot_table_entries':
    ensure => 'present',
    val    => $sunrpc_tcp_slot_table_entries,
    silent => true,
    notify => Service[$::nfs::service_names::nfs_server]
  }

  sysctl { 'sunrpc.udp_slot_table_entries':
    ensure => 'present',
    val    => $sunrpc_udp_slot_table_entries,
    silent => true,
    notify => Service[$::nfs::service_names::nfs_server]
  }

  if $::nfs::secure_nfs {
    if !empty($::nfs::service_names::rpcsvcgssd) {
      service { $::nfs::service_names::rpcsvcgssd :
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true
      }

      Service[$::nfs::service_names::rpcbind] -> Service[$::nfs::service_names::rpcsvcgssd]
    }

    Service[$::nfs::service_names::rpcbind] -> Sysctl['sunrpc.tcp_slot_table_entries']
    Service[$::nfs::service_names::rpcbind] -> Sysctl['sunrpc.udp_slot_table_entries']
    Sysctl['sunrpc.tcp_slot_table_entries'] ~> Service[$::nfs::service_names::nfs_lock]
    Sysctl['sunrpc.udp_slot_table_entries'] ~> Service[$::nfs::service_names::nfs_lock]
  }
}
