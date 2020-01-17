# @summary NFS server firewall configuration for NFSv3 and NFSv4
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::server::firewall::nfsv3and4
{
  assert_private()

  $_base_ports = [
    111, # rpcbind port
    $nfs::server::nfsd_port,
    $nfs::server::rquotad_port,
    $nfs::server::mountd_port,
    $nfs::statd_port
  ]

  $_tcp_ports = $_base_ports + [ $nfs::lockd_port ]
  iptables::listen::tcp_stateful { 'nfs_client_tcp_ports':
    trusted_nets => $nfs::server::trusted_nets,
    dports       => $_tcp_ports
  }

  $_udp_ports = $_base_ports + [ $nfs::lockd_udp_port]
  iptables::listen::udp { 'nfs_client_udp_ports':
    trusted_nets => $nfs::server::trusted_nets,
    dports       => $_udp_ports
  }
}
