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
#   * See ``stunnel::connection::verify`` for details
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
  Simplib::Netlist $trusted_nets           = $::nfs::server::trusted_nets,
  Simplib::IP      $nfs_accept_address     = '0.0.0.0',
  Simplib::Port    $nfs_accept_port        = 20490,
  Simplib::Port    $portmapper_accept_port = 1110,
  Simplib::Port    $rquotad_accept_port    = 8750,
  Simplib::Port    $nlockmgr_accept_port   = 32804,
  Simplib::Port    $mountd_accept_port     = 8920,
  Simplib::Port    $status_accept_port     = 6620
) {
  include '::nfs::server'
  include '::stunnel'

  Service[$::nfs::service_names::nfs_server] -> Service['stunnel']

  if $version == 4 {
    stunnel::connection { 'nfs':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => [2049],
      accept       => "${nfs_accept_address}:${nfs_accept_port}",
      verify       => $verify
    }

    $stunnel_port_override = [ $nfs_accept_port ]
  }
  else {
    stunnel::connection { 'nfs':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => ['2049'],
      accept       => "${nfs_accept_address}:${nfs_accept_port}",
      verify       => $verify
    }
    stunnel::connection { 'portmapper':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => ['111'],
      accept       => "${nfs_accept_address}:${portmapper_accept_port}",
      verify       => $verify
    }
    stunnel::connection { 'rquotad':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => [$::nfs::rquotad_port],
      accept       => "${nfs_accept_address}:${rquotad_accept_port}",
      verify       => $verify
    }
    stunnel::connection { 'nlockmgr':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => [$::nfs::lockd_tcpport],
      accept       => "${nfs_accept_address}:${nlockmgr_accept_port}",
      verify       => $verify
    }
    stunnel::connection { 'mountd':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => [$::nfs::mountd_port],
      accept       => "${nfs_accept_address}:${mountd_accept_port}",
      verify       => $verify
    }
    stunnel::connection { 'status':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => [$::nfs::statd_port],
      accept       => "${nfs_accept_address}:${status_accept_port}",
      verify       => $verify
    }

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
