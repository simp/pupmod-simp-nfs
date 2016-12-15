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
# @param nfs_server
#
# @param version The version of NFS to use.  This has been tested for
#   NFS versions 3 and 4
#
# @param nfs_accept_port The stunnel local accept port.
#
# @param nfs_connect_port The stunnel remote connection port.
#
# @param portmapper_accept_port The portmapper local accept port.
#
# @param portmapper_connect_port The portmapper remote connection port.
#
# @param rquotad_connect_port The rquotad remote connection port.
#
# @param lockd_connect_port The lockd remote connection port.
#
# @param mountd_connect_port The mountd remote connection port.
#
# @param statd_connect_port The statd remote connection port.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
# @author Kendall Moore <kendall.moore@onyxpoint.com>
#
class nfs::client::stunnel(
  String                   $nfs_server              = $::nfs::client::nfs_server,
  Stdlib::Compat::Integer  $version                 = '4',
  Stdlib::Compat::Integer  $nfs_accept_port         = '2049',
  Stdlib::Compat::Integer  $nfs_connect_port        = '20490',
  Stdlib::Compat::Integer  $portmapper_accept_port  = '111',
  Stdlib::Compat::Integer  $portmapper_connect_port = '1110',
  Stdlib::Compat::Integer  $rquotad_connect_port    = '8750',
  Stdlib::Compat::Integer  $lockd_connect_port      = '32804',
  Stdlib::Compat::Integer  $mountd_connect_port     = '8920',
  Stdlib::Compat::Integer  $statd_connect_port      = '6620',
) inherits ::nfs::client {

  validate_net_list($nfs_server)
  validate_port($nfs_accept_port)
  validate_port($nfs_connect_port)
  validate_port($portmapper_accept_port)
  validate_port($portmapper_connect_port)
  validate_port($rquotad_connect_port)
  validate_port($lockd_connect_port)
  validate_port($mountd_connect_port)
  validate_port($statd_connect_port)

  # Don't do this if you're running on yourself because, well, it's bad!
  if !host_is_me($nfs_server) {
    include '::stunnel'

    if $version == '4' {
      stunnel::add { 'nfs_client':
        connect => ["${nfs_server}:${nfs_connect_port}"],
        accept  => "127.0.0.1:${nfs_accept_port}"
      }
    }
    else {
      stunnel::add { 'nfs_client':
        connect => ["${nfs_server}:${nfs_connect_port}"],
        accept  => "127.0.0.1:${nfs_accept_port}"
      }
      stunnel::add { 'portmapper':
        connect => ["${nfs_server}:${portmapper_connect_port}"],
        accept  => "127.0.0.1:${portmapper_accept_port}",
        require => Service[$::nfs::service_names::rpcbind]
      }
      stunnel::add { 'rquotad':
        connect => ["${nfs_server}:${rquotad_connect_port}"],
        accept  => "127.0.0.1:${::nfs::rquotad_port}"
      }
      stunnel::add { 'lockd':
        connect => ["${nfs_server}:${lockd_connect_port}"],
        accept  => "127.0.0.1:${::nfs::lockd_tcpport}"
      }
      stunnel::add { 'mountd':
        connect => ["${nfs_server}:${mountd_connect_port}"],
        accept  => "127.0.0.1:${::nfs::mountd_port}"
      }
      stunnel::add { 'status':
        connect => ["${nfs_server}:${statd_connect_port}"],
        accept  => "127.0.0.1:${::nfs::statd_port}"
      }
    }
  }
}
