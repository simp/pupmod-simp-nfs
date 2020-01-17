# @summary NFS server firewall configuration for NFSv4 only
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::server::firewall::nfsv4
{
  assert_private()

  $_ports = [
    111, # rpcbind port; rpcbind required for rpc.rquotad
    $nfs::server::nfsd_port,
    $nfs::server::rquotad_port
  ]

  iptables::listen::tcp_stateful { 'nfs_client_tcp_ports':
    trusted_nets => $nfs::server::trusted_nets,
    dports       => $_ports
  }

  iptables::listen::udp { 'nfs_client_udp_ports':
    trusted_nets => $nfs::server::trusted_nets,
    dports       => $_ports
  }

}
