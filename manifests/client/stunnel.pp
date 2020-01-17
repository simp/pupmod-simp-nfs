# @summary Connect to an NFSv4 server over stunnel
#
# No stunnel connection can be made to the local system due to the likelihood
# of a port conflict. So if you're connecting to the local system, a direct
# connection is required.
#
# When you know this host is also the NFS server, configuring the mount for
# a direct connection to `127.0.0.1` is best.  However, this *attempts* to
# determine if the host is trying to connect to itself and use a direct, local
# connection in lieu of a stunnel in this case.
#
# * Auto-detect logic only works with IPv4 addresses.
# * When the auto-detect logic detects a local connection, this define does not
#   need to do anything further, because `nfs::client::mount` has already set
#   the NFS server IP to `127.0.0.1` in the mount.
#
# @param name [Simplib::Host::Port]
#   An `<ip>:<port>` combination to the remote NFSv4 server
#
#   * The `port` is the listening port of the NFS server daemon.
#
# @param nfs_server
#   The IP address of the NFS server to which you will be connecting
#
# @param nfsd_accept_port
#   The NFS server daemon listening port
#
# @param nfsd_connect_port
#    Listening port on the NFS server for the tunneled connection to
#    the NFS server daemon
#
# @param stunnel_socket_options
#   Additional stunnel socket options to be applied to the stunnel to the NFS
#   server
#
# @param stunnel_verify
#   The level at which to verify TLS connections
#
# @param stunnel_wantedby
#   The `systemd` targets that need `stunnel` to be active prior to being
#   activated
#
# @param firewall
#   Use the SIMP `iptables` module to manage firewall connections
#
# @param tcpwrappers
#   Use the SIMP `tcpwrappers` module to manage TCP wrappers
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
define nfs::client::stunnel(
  Simplib::Ip   $nfs_server,
  Simplib::Port $nfsd_accept_port,
  Simplib::Port $nfsd_connect_port,
  Array[String] $stunnel_socket_options,
  Integer[0]    $stunnel_verify,
  Array[String] $stunnel_wantedby,
  Boolean       $firewall,
  Boolean       $tcpwrappers
) {
  assert_private()

  # When you are connecting to a collocated NFS server, the stunnel is
  # unnecessary and the destination IP has already been correctly configured
  # to be 127.0.0.1.
  unless simplib::host_is_me($nfs_server) {
    simplib::assert_optional_dependency($module_name, 'simp/stunnel')

    stunnel::instance { "nfs_${name}_client_nfsd":
      connect          => ["${nfs_server}:${nfsd_connect_port}"],
      accept           => "127.0.0.1:${nfsd_accept_port}",
      verify           => $stunnel_verify,
      socket_options   => $stunnel_socket_options,
      systemd_wantedby => $stunnel_wantedby,
      firewall         => $firewall,
      tcpwrappers      => $tcpwrappers,
      tag              => ['nfs']
    }
  }
}
