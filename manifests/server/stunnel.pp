# Configures a server for NFS over stunnel
#
# Known to work with ``NFSv3`` and ``NFSv4``.
#
# @param version
#   The version of NFS to use
#
# @param verify
#   The verification level that should be done on the clients
#
#   * See ``stunnel::instance::verify`` for details
#
# @param trusted_nets
#   The systems that are allowed to connect to this service
#
#   * Set to 'any' or 'ALL' to allow the world
#
# param statd_port
# @param nfs_accept_address
#   The address upon which the NFS server will listen
#
#   * You should be set this to ``0.0.0.0`` for all interfaces
#
# @param nfs_accept_port
#
# @param portmapper_accept_port
# @param rquotad_accept_port
# @param nlockmgr_accept_port
# @param mountd_accept_port
# @param status_accept_port
#
# @author Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
# @author Kendall Moore <mailto:kmoore@keywcorp.com>
#
class nfs::server::stunnel (
  Integer[3,4]     $version                = 4,
  Integer          $verify                 = 2,
  Simplib::Netlist $trusted_nets           = $nfs::server::trusted_nets,
  Simplib::IP      $nfs_accept_address     = '0.0.0.0',
  Simplib::Port    $nfs_accept_port        = 20490,
  Simplib::Port    $portmapper_accept_port = 1110,
  Simplib::Port    $rquotad_accept_port    = 8750,
  Simplib::Port    $nlockmgr_accept_port   = 32804,
  Simplib::Port    $mountd_accept_port     = 8920,
  Simplib::Port    $status_accept_port     = 6620,
  Boolean          $stunnel_systemd_deps   = $nfs::stunnel_systemd_deps,
  Array[String]    $stunnel_wantedby       = $nfs::stunnel_wantedby
) {
  include '::nfs::service_names'

  if $stunnel_systemd_deps and ($facts['os']['release']['major'] > '6') {
    $_stunnel_wantedby = [
      $nfs::service_names::nfs_lock,
      $nfs::service_names::nfs_mountd,
      $nfs::service_names::nfs_rquotad,
      $nfs::service_names::nfs_server,
      $nfs::service_names::rpcbind,
      $nfs::service_names::rpcidmapd,
      $nfs::service_names::rpcgssd,
      $nfs::service_names::rpcsvcgssd,
    ]
  }
  else {
    $_stunnel_wantedby = undef
  }

  if $version == 4 {
    stunnel::instance { 'nfs':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [2049],
      accept           => "${nfs_accept_address}:${nfs_accept_port}",
      verify           => $verify,
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }

    $stunnel_port_override = [ $nfs_accept_port ]

    Service[$::nfs::service_names::nfs_server] -> Stunnel::Instance['nfs']
  }
  else {
    stunnel::instance { 'nfs':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => ['2049'],
      accept           => "${nfs_accept_address}:${nfs_accept_port}",
      verify           => $verify,
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'portmapper':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => ['111'],
      accept           => "${nfs_accept_address}:${portmapper_accept_port}",
      verify           => $verify,
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'rquotad':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [$::nfs::rquotad_port],
      accept           => "${nfs_accept_address}:${rquotad_accept_port}",
      verify           => $verify,
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'nlockmgr':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [$::nfs::lockd_tcpport],
      accept           => "${nfs_accept_address}:${nlockmgr_accept_port}",
      verify           => $verify,
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'mountd':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [$::nfs::mountd_port],
      accept           => "${nfs_accept_address}:${mountd_accept_port}",
      verify           => $verify,
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'status':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [$::nfs::statd_port],
      accept           => "${nfs_accept_address}:${status_accept_port}",
      verify           => $verify,
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }

    Service[$::nfs::service_names::nfs_server] -> Stunnel::Instance['nfs']
    Service[$::nfs::service_names::nfs_server] -> Stunnel::Instance['portmapper']
    Service[$::nfs::service_names::nfs_server] -> Stunnel::Instance['rquotad']
    Service[$::nfs::service_names::nfs_server] -> Stunnel::Instance['nlockmgr']
    Service[$::nfs::service_names::nfs_server] -> Stunnel::Instance['mountd']
    Service[$::nfs::service_names::nfs_server] -> Stunnel::Instance['status']

    $stunnel_port_override = [
      $nfs_accept_port,
      $portmapper_accept_port,
      $rquotad_accept_port,
      $nlockmgr_accept_port,
      $mountd_accept_port,
      $status_accept_port
    ]
  }
}
