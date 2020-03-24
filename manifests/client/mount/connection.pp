# @summary Manage cross-system connectivity parts of a mount
#
# @param nfs_server
#   The IP address of the NFS server to which you will be connecting
#
# @param nfs_version
#   The NFS major version that you want to use.
#
# @param nfsd_port
#   The NFS server daemon listening port
#
# @param firewall
#   Use the SIMP `iptables` module to manage firewall connections
#
# @param stunnel
#   Controls enabling `stunnel` for this connection
#
#   * Unused when `$stunnel` is `false`
#
# @param stunnel_nfsd_port
#    Listening port on the NFS server for the tunneled connection to
#    the NFS server daemon
#
#   * Decrypted traffic will be forwarded to `$nfsd_port` on the NFS server
#   * Unused when `$stunnel` is `false`
#
# @param stunnel_socket_options
#   Additional stunnel socket options to be applied to the stunnel to the NFS
#   server
#
#   * Unused when `$stunnel` is `false`
#
# @param stunnel_verify
#   The level at which to verify TLS connections
#
#   * Levels:
#
#       * level 0 - Request and ignore peer certificate.
#       * level 1 - Verify peer certificate if present.
#       * level 2 - Verify peer certificate.
#       * level 3 - Verify peer with locally installed certificate.
#       * level 4 - Ignore CA chain and only verify peer certificate.
#
#   * Unused when `$stunnel` is `false`
#
# @param stunnel_wantedby
#   The `systemd` targets that need `stunnel` to be active prior to being
#   activated
#
#   * Unused when `$stunnel` is `false`
#
# @param tcpwrappers
#   Use the SIMP `tcpwrappers` module to manage TCP wrappers
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
define nfs::client::mount::connection (
  Simplib::Ip   $nfs_server,
  Integer[3,4]  $nfs_version,
  Simplib::Port $nfsd_port,
  Boolean       $firewall,
  Boolean       $stunnel,
  Simplib::Port $stunnel_nfsd_port,
  Array[String] $stunnel_socket_options,
  Integer       $stunnel_verify,
  Array[String] $stunnel_wantedby,
  Boolean       $tcpwrappers
) {

  # This is only meant to be called from inside nfs::client::mount
  assert_private()

  if $stunnel and ($nfs_version == 4) {
    # It is possible that this is called for multiple mounts on the same server.
    # stunnel-related firewall and tcpwrappers settings handled by the
    # stunnel::instance, itself.
    ensure_resource('nfs::client::stunnel',
      "${nfs_server}:${nfsd_port}",
      {
        nfs_server             => $nfs_server,
        nfsd_accept_port       => $nfsd_port,
        nfsd_connect_port      => $stunnel_nfsd_port,
        stunnel_socket_options => $stunnel_socket_options,
        stunnel_verify         => $stunnel_verify,
        stunnel_wantedby       => $stunnel_wantedby,
        firewall               => $firewall,
        tcpwrappers            => $tcpwrappers
      }
    )
  } elsif $firewall  {
    # Open up the firewall for incoming, side-band NFS channels.

    if ($nfs_version == 4) {
      # Set up the NFSv4.0 delegation callback port IPTables opening.  This is
      # only needed for NFSv4.0, because, beginning with NFSv4.1, delegation
      # does not require a side channel. However, unless the mount specifies
      # the minor NFSv4 version, we cannot be assured NFSv4.0 will not be the
      # version used. This is because in the absence of a specified minor NFS
      # version, the client negotiates with the NFS server to determine the
      # minor version.

      # It is possible that this is called for multiple mounts on the same server
      ensure_resource('iptables::listen::tcp_stateful',
        "nfs_callback_${nfs_server}",
        {
          trusted_nets => [$nfs_server],
          # the port to use is communicated via the main nfsd channel, so no
          # need for rpcbind
          dports       => [$nfs::client::callback_port]
        }
      )
    } else {
      # In NFSv3, the NFS server will reach out to the client in NLM and NSM
      # protos (i.e., locking and recovery from locking upon server/client
      # reboot). The NFS server uses rpcbind to figure out the client's ports
      # for this communication.
      #
      # TODO Restrict source port to the server's configured (not ephemeral)
      # outgoing statd and statd-notify ports as appropriate.
      #
      $_rpcbind_port = 111
      $_tcp_status_ports = [
        $_rpcbind_port,
        $nfs::lockd_port,
        $nfs::statd_port
      ]
      ensure_resource('iptables::listen::tcp_stateful',
        "nfs_status_tcp_${nfs_server}",
        {
          trusted_nets => [$nfs_server],
          dports       => $_tcp_status_ports
        }
      )

      $_udp_status_ports = [
        $_rpcbind_port,
        $nfs::lockd_udp_port,
        $nfs::statd_port
      ]
      ensure_resource('iptables::listen::udp',
        "nfs_status_udp_${nfs_server}",
        {
          trusted_nets => [$nfs_server],
          dports       => $_udp_status_ports
        }
      )
    }
  }
}
