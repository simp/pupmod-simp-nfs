# == Class: nfs::server
#
# This class configure a NFS server with a default configuration that
# nails up the ports so that you can pass them through iptables.
#
# This defaults to NFSv4.
#
# == Parameters
#
# [*client_ips*]
#   Required
#   Accepts: CIDR formatted client IP addresses.
#   The systems that are allowed to connect to this service, as an array. Set
#   to 'any' or 'ALL' to allow the world.
#
# [*rpcrquotadopts*]
#   Accepts: String
#   Default: ''
#   Options that should be passed to rquotad at start time. Not
#   validated.
#
# [*lockd_arg*]
#   Accepts: String
#   Default: ''
#   Arbitrary options that should be passed to lockd.
#
# [*nfsd_module*]
#   Accepts: '<blank>|noload'
#   Default: ''
#   If set to 'noload' will prevent the nfsd module from being
#   pre-loaded.
#
# [*rpcmountdopts*]
#   Accepts: String
#   Default: ''
#   An arbitrary string of options to pass to mountd.
#
# [*statdarg*]
#   Accepts: String
#   Default: ''
#   An arbitrary string of options to pass to statd.
#
# [*statd_ha_callout*]
#   Accepts: '<blank>|fully qualified path'
#   Default: ''
#   The fully qualified path of an application that should be used for
#   statd HA.
#
# [*rpcidmapdargs*]
#   Accepts: String
#   Default: ''
#   Artibrary arguments to pass to idmapd.
#
# [*rpcgssdargs*]
#   Accepts: String
#   Default: ''
#   Arbitrary arguments to pass to gssd.
#
# [*rpcsvcgssdargs*]
#   Accepts: String
#   Default: ''
#   Arbitrary arguments to pass to svcgssd.
#
# [*sunrpc_udp_slot_table_entries*]
#   Accepts: Integer
#   Default: 128
#   Raise the default udp slot table entries in the kernel.
#   Most NFS server performance guides seem to recommend this setting.
#   If you have a low memory system, you may want to reduce this.
#
# [*sunrpc_tcp_slot_table_entries*]
#   Accepts: Integer
#   Default: 128
#   Raise the default tcp slot table entries in the kernel.
#   Most NFS server performance guides seem to recommend this setting.
#   If you have a low memory system, you may want to reduce this.
#
# === Caveats
#
# * Due to some bug in Red Hat, $mountd_nfs_v1 must be set to 'yes' to
#   properly unmount.
# * The rpcbind port and the rpc.quotad ports are open to the client
#   networks so that the 'quota' command works on the clients.
#
# == Authors
#
# * Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
# * Morgan Haskel <mailto:morgan.haskel@onyxpoint.com>
# * Kendall Moore <mailto:kmoore@keywcorp.com>
#
class nfs::server (
  $client_ips,
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
  $sunrpc_tcp_slot_table_entries = '128'
){
  include '::nfs'
  include '::tcpwrappers'

  validate_net_list($client_ips)
  validate_integer($sunrpc_udp_slot_table_entries)
  validate_integer($sunrpc_tcp_slot_table_entries)

  concat_build { 'nfs':
    order => '*.export'
  }

  exec { 'nfs_re-export':
    command     => '/usr/sbin/exportfs -ra',
    refreshonly => true,
    require     => Package['nfs-utils']
  }

  service { $nfs::service_names::nfs_server :
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => Service[$nfs::service_names::rpcbind]
  }

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
  if $::nfs::server::stunnel::stunnel_port_override {
    iptables::add_tcp_stateful_listen { 'nfs_client_tcp_ports':
      client_nets => $client_ips,
      dports      => $::nfs::server::stunnel::stunnel_port_override
    }
    iptables::add_udp_listen { 'nfs_client_udp_ports':
      client_nets => $client_ips,
      dports      => $::nfs::server::stunnel::stunnel_port_override
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

    iptables::add_tcp_stateful_listen { 'nfs_client_tcp_ports':
      client_nets => $client_ips,
      dports      => $lports
    }
    iptables::add_udp_listen { 'nfs_client_udp_ports':
      client_nets => $client_ips,
      dports      => $lports
    }
  }

#  if $nfs::secure_nfs {
    # Enable this when we integrate Kerberos.
    #service { 'rpcsvcgssd':
    #  enable     => 'true',
    #  ensure     => 'running',
    #  hasrestart => 'true',
    #  hasstatus  => 'true',
    #  require    => Service[$nfs::service_names::rpcbind]
    #}
#  }

  service { 'sunrpc_tuning':
    enable  => true,
    require => File['/etc/init.d/sunrpc_tuning']
  }

  if $::nfs::secure_nfs {
    sysctl::value { 'sunrpc.tcp_slot_table_entries':
      value   => $sunrpc_tcp_slot_table_entries,
      silent  => true,
      notify  => [
        Service[$::nfs::service_names::nfs_server],
        Service[$::nfs::service_names::nfs_lock],
      ],
      require => Service[$::nfs::service_names::rpcgssd]
    }

    sysctl::value { 'sunrpc.udp_slot_table_entries':
      value   => $sunrpc_udp_slot_table_entries,
      silent  => true,
      notify  => [
        Service[$::nfs::service_names::nfs_server],
        Service[$::nfs::service_names::nfs_lock],
      ],
      require => Service[$::nfs::service_names::rpcgssd]
    }
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

  if $::nfs::use_stunnel {
    include '::nfs::server::stunnel'

    # This is here due to some bug where allowing things through regularly
    # isn't working correctly.
    tcpwrappers::allow { 'nfs': pattern => 'ALL' }
  }
}
