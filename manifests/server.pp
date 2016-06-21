# Configure a NFS server with a default configuration that nails up the ports
# so that you can pass them through iptables.
#
# This defaults to NFSv4.
#
# @param client_ips [Net List] The systems that are allowed to connect to this
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
#
# @param rpcmountdopts [String] An arbitrary string of options to pass to
#   mountd.
#
# @param statdarg [String] An arbitrary string of options to pass to statd.
#
# @param statd_ha_callout [Absolute Path] The fully path of an application that
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
# @param simp_iptables [Boolean] If set, use the SIMP iptables module to manage
#   firewall connections.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
# @author Morgan Rhodes <morgan@puppet.com>
# @author Kendall Moore <kendall.moore@onyxpoint.com>
#
class nfs::server (
  $client_ips,
  $nfsv3 = $::nfs::nfsv3,
  $rpcrquotadopts= '',
  $lockd_arg = '',
  $nfsd_module = '',
  $rpcmountdopts = '',
  $statdarg = '',
  $statd_ha_callout = '',
  $rpcidmapdargs = '',
  $rpcgssdargs = '',
  $rpcsvcgssdargs = '',
  $sunrpc_udp_slot_table_entries = '128',
  $sunrpc_tcp_slot_table_entries = '128',
  $simp_iptables = $::nfs::simp_iptables
) inherits ::nfs {

  include '::tcpwrappers'

  if $::nfs::use_stunnel {
    include '::nfs::server::stunnel'

    # This is here due to some bug where allowing things through regularly
    # isn't working correctly.
    tcpwrappers::allow { 'nfs': pattern => 'ALL' }
  }

  validate_net_list($client_ips)
  validate_bool($nfsv3)
  validate_string($rpcrquatadopts)
  validate_string($lockd_arg)
  validate_string($nfsd_module)
  validate_string($rpcmountdopts)
  validate_string($statdarg)
  if !empty($statd_ha_callout) { validate_absolute_path($statd_ha_callout) }
  validate_string($rpcidmapdargs)
  validate_string($rpcgssdargs)
  validate_string($rpcsvcgssdargs)
  validate_integer($sunrpc_udp_slot_table_entries)
  validate_integer($sunrpc_tcp_slot_table_entries)
  validate_bool($simp_iptables)

  if $nfsv3 { include '::nfs::idmapd' }

  concat_build { 'nfs':
    order  => '*.export',
    quiet  => true,
    target => '/etc/exports'
  }

  file { '/etc/exports':
    ensure    => 'file',
    mode      => '0640',
    owner     => 'root',
    group     => 'root'
  }

  exec { 'nfs_re-export':
    command     => '/usr/sbin/exportfs -ra',
    refreshonly => true,
    require     => Package['nfs-utils']
  }

  Concat_build['nfs'] -> File['/etc/exports']
  File['/etc/exports'] ~> Exec['nfs_re-export']
  Concat_build['nfs'] ~> Exec['nfs_re-export']

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
  if $::nfs::use_stunnel and $::nfs::server::stunnel::stunnel_port_override {
    if $simp_iptables {
      include '::iptables'

      iptables::add_tcp_stateful_listen { 'nfs_client_tcp_ports':
        client_nets => $client_ips,
        dports      => $::nfs::server::stunnel::stunnel_port_override
      }
      iptables::add_udp_listen { 'nfs_client_udp_ports':
        client_nets => $client_ips,
        dports      => $::nfs::server::stunnel::stunnel_port_override
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

    if $simp_iptables {
      iptables::add_tcp_stateful_listen { 'nfs_client_tcp_ports':
        client_nets => $client_ips,
        dports      => $lports
      }
      iptables::add_udp_listen { 'nfs_client_udp_ports':
        client_nets => $client_ips,
        dports      => $lports
      }
    }
  }

  service { 'sunrpc_tuning':
    enable  => true,
    require => File['/etc/init.d/sunrpc_tuning']
  }

  tcpwrappers::allow { [
    'mountd',
    'statd',
    'rquotad',
    'lockd',
    'rpcbind'
    ]:
    pattern => $client_ips
  }

  if $::nfs::secure_nfs {
    service { $::nfs::service_names::rpcsvcgssd :
      enable     => 'true',
      ensure     => 'running',
      hasrestart => 'true',
      hasstatus  => 'true'
    }

    sysctl::value { 'sunrpc.tcp_slot_table_entries':
      value   => $sunrpc_tcp_slot_table_entries,
      silent  => true,
      notify  => Service[$::nfs::service_names::nfs_server]
    }

    sysctl::value { 'sunrpc.udp_slot_table_entries':
      value   => $sunrpc_udp_slot_table_entries,
      silent  => true,
      notify  => Service[$::nfs::service_names::nfs_server]
    }

    Service[$::nfs::service_names::rpcbind] -> Service[$::nfs::service_names::rpcsvcgssd]
    Service[$::nfs::service_names::rpcbind] -> Sysctl::Value['sunrpc.tcp_slot_table_entries']
    Service[$::nfs::service_names::rpcbind] -> Sysctl::Value['sunrpc.udp_slot_table_entries']
    Sysctl::Value['sunrpc.tcp_slot_table_entries'] ~> Service[$::nfs::service_names::nfs_lock]
    Sysctl::Value['sunrpc.udp_slot_table_entries'] ~> Service[$::nfs::service_names::nfs_lock]
  }
}
