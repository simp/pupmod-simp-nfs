# Configures a server for NFSv4 over stunnel
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::server::stunnel {

  assert_private()

  # Only NFS > 4.0 can operate fully within one stunnel of the main nfsd
  # port.
  # - NFSv4.0 has a client callback sideband channel required for client
  #   delegations. Since each NFS client would be the stunnel server for this
  #   connection, the only way to configure callback stunnels is to a priori
  #   tell the NFS server the exact list of NFS clients it is serving. In
  #   other words, the NFS server needs to know where to connect to for
  #   the callback stunnel. This is not practical.
  # - NFSv3 has multiple sideband channels, one of which, per the nfs man
  #   page exclusively uses UDP (NSM notifications from client to server).
  #
  # This individual stunnel does not extend to RPC calls for quota commands.
  # Unfortunately, we cannot tunnel connections to rpc-rquotad AND support
  # multi-server client mounts. This is because a client uses rpcbind to
  # determine the server's rquotad port (quota commands do not allow the port
  # to be specified), the rpcbind port is not effectively configurable, and so
  # only one stunnel for the rpcbind port can be created. A unique rpcbind
  # tunnel from the client would be required for each unique NFS server.
  #
  # The end result of the rpcbind limitation is that when tunneling is used,
  # users can only run quota commands on the NFS server.  Without tunneling,
  # users can run those commands on the NFS clients a well.

  simplib::assert_optional_dependency($module_name, 'simp/stunnel')

  $_accept = "${nfs::server::stunnel_accept_address}:${nfs::server::stunnel_nfsd_accept_port}"
  stunnel::instance { 'nfsd':
    client           => false,
    trusted_nets     => $nfs::server::trusted_nets,
    connect          => [$nfs::server::nfsd_port],
    accept           => $_accept,
    verify           => $nfs::server::stunnel_verify,
    socket_options   => $nfs::server::stunnel_socket_options,
    systemd_wantedby => $nfs::server::stunnel_wantedby,
    firewall         => $nfs::firewall,
    tcpwrappers      => $nfs::tcpwrappers,
    tag              => ['nfs']
  }
}
