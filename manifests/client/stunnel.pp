# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# Connect to an NFSv3 server over stunnel
#
# Due to the nature of Stunnel and NFSv3, you can only have **one** of these in
# your environment.
#
# It is **highly** recommended that you use Kerberos and NFSv4 in all cases.
# This is here in case this is not feasible.
#
# If you are using NFSv4 you should use the ``nfs::client::stunnel::v4``
# Defined Type directly and you must **explicitly** specify your local port so
# that you don't have an stunnel port conflict.
#
# @param nfs_server
#   The host to which you wish to connect
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
# @param stunnel_verify
#   What level to verify the TLS connection via stunnel
#
#   * See ``stunnel::instance::verify`` for details
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
# @author Kendall Moore <kendall.moore@onyxpoint.com>
#
class nfs::client::stunnel (
  Simplib::Host $nfs_server,
  Simplib::Port $nfs_accept_port         = 2049,
  Simplib::Port $nfs_connect_port        = 20490,
  Simplib::Port $portmapper_accept_port  = 111,
  Simplib::Port $portmapper_connect_port = 1110,
  Simplib::Port $rquotad_connect_port    = 8750,
  Simplib::Port $lockd_connect_port      = 32804,
  Simplib::Port $mountd_connect_port     = 8920,
  Simplib::Port $statd_connect_port      = 6620,
  Integer[0]    $stunnel_verify          = $nfs::client::stunnel_verify,
  Boolean       $stunnel_systemd_deps    = $nfs::stunnel_systemd_deps,
  Array[String] $stunnel_wantedby        = $nfs::stunnel_wantedby
) inherits ::nfs::client {

  if $stunnel_systemd_deps {
    $_stunnel_wantedby = [
      'remote-fs-pre.target',
    ]
  }
  else {
    $_stunnel_wantedby = undef
  }

  # Don't do this if you're running on yourself because, well, it's bad!
  if !host_is_me($nfs_server) {
    stunnel::instance { 'nfs_client':
      connect          => ["${nfs_server}:${nfs_connect_port}"],
      accept           => "127.0.0.1:${nfs_accept_port}",
      verify           => $stunnel_verify,
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }

    stunnel::instance { 'nfs_client_portmapper':
      connect          => ["${nfs_server}:${portmapper_connect_port}"],
      accept           => "127.0.0.1:${portmapper_accept_port}",
      verify           => $stunnel_verify,
      require          => Service[$::nfs::service_names::rpcbind],
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }

    stunnel::instance { 'nfs_client_rquotad':
      connect          => ["${nfs_server}:${rquotad_connect_port}"],
      accept           => "127.0.0.1:${::nfs::rquotad_port}",
      verify           => $stunnel_verify,
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'nfs_client_lockd':
      connect          => ["${nfs_server}:${lockd_connect_port}"],
      accept           => "127.0.0.1:${::nfs::lockd_tcpport}",
      verify           => $stunnel_verify,
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'nfs_client_mountd':
      connect          => ["${nfs_server}:${mountd_connect_port}"],
      accept           => "127.0.0.1:${::nfs::mountd_port}",
      verify           => $stunnel_verify,
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'nfs_client_status':
      connect          => ["${nfs_server}:${statd_connect_port}"],
      accept           => "127.0.0.1:${::nfs::statd_port}",
      verify           => $stunnel_verify,
      socket_options   => $::nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
  }
}
