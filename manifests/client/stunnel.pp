# Connect to an NFS server over stunnel
#
# You may need to change 'nfs_accept_port' to something different if you're
# targeting different servers using multiple tunnels.
#
# This is limited in that the migration features of NFS4 may not function since
# the callback port is not exposed via a reverse tunnel. This will be rectified
# when Kerberos is added to the systems.
#
# Due to the nature of Stunnel, you can only have *one* of these in your
# environment. If you need encrypted connections to multiple systems, you can
# either inheirit and enhance this class or you can use Kerberos (preferred).
#
# @param version
#   The version of NFS to use
#
#   * This has been tested for NFS versions 3 and 4
#
# @param nfs_accept_port
#   The ``stunnel`` local accept port
#
# @param nfs_connect_port
#   The ``stunnel`` remote connection port
#
# @param portmapper_accept_port
#   The ``portmapper`` local accept port
#
# @param portmapper_connect_port
#   The ``portmapper`` remote connection port
#
# @param rquotad_connect_port
#   The ``rquotad`` remote connection port
#
# @param lockd_connect_port
#   The ``lockd`` remote connection port
#
# @param mountd_connect_port
#   The ``mountd`` remote connection port
#
# @param statd_connect_port
#   The ``statd`` remote connection port
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
# @author Kendall Moore <kendall.moore@onyxpoint.com>
#
class nfs::client::stunnel(
  Simplib::Netlist $nfs_servers             = $::nfs::client::nfs_servers,
  Integer[3,4]     $version                 = 4,
  Simplib::Port    $nfs_accept_port         = 2049,
  Simplib::Port    $nfs_connect_port        = 20490,
  Simplib::Port    $portmapper_accept_port  = 111,
  Simplib::Port    $portmapper_connect_port = 1110,
  Simplib::Port    $rquotad_connect_port    = 8750,
  Simplib::Port    $lockd_connect_port      = 32804,
  Simplib::Port    $mountd_connect_port     = 8920,
  Simplib::Port    $statd_connect_port      = 6620,
) inherits ::nfs::client {
  # Don't do this if you're running on yourself because, well, it's bad!
  if !host_is_me($nfs_servers) {
    include '::stunnel'

    stunnel::connection { 'nfs_client':
      connect => map($nfs_servers) |$svr| { "${svr}:${nfs_connect_port}" },
      accept  => "127.0.0.1:${nfs_accept_port}"
    }

    if $version != 4 {
      stunnel::connection { 'nfs_portmapper':
        connect => map($nfs_servers) |$svr| { "${svr}:${portmapper_connect_port}" },
        accept  => "127.0.0.1:${portmapper_accept_port}",
        require => Service[$::nfs::service_names::rpcbind]
      }
      stunnel::connection { 'nfs_rquotad':
        connect => map($nfs_servers) |$svr| { "${svr}:${rquotad_connect_port}" },
        accept  => "127.0.0.1:${::nfs::rquotad_port}"
      }
      stunnel::connection { 'nfs_lockd':
        connect => map($nfs_servers) |$svr| { "${svr}:${lockd_connect_port}" },
        accept  => "127.0.0.1:${::nfs::lockd_tcpport}"
      }
      stunnel::connection { 'nfs_mountd':
        connect => map($nfs_servers) |$svr| { "${svr}:${mountd_connect_port}" },
        accept  => "127.0.0.1:${::nfs::mountd_port}"
      }
      stunnel::connection { 'nfs_status':
        connect => map($nfs_servers) |$svr| { "${svr}:${statd_connect_port}" },
        accept  => "127.0.0.1:${::nfs::statd_port}"
      }
    }
  }
}
