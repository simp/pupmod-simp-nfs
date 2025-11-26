# @summary Configure TCP wrappers for NFS client services
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::client::tcpwrappers {

  assert_private()

  # TCP wrappers was dropped in EL8
  if $nfs::manage_tcpwrappers and $nfs::nfsv3 {
    include 'tcpwrappers'

    # On EL7, the following NFS-client-related executables are dynamically
    # linked to libwrap:
    # * rpc.statd; man page says TCP wrappers under daemon name 'statd'
    # * rpcbind

    # Both resources in common with nfs::server, which may be on this node.
    $_allow_options = { pattern => $nfs::trusted_nets }
    ensure_resource('tcpwrappers::allow', 'rpcbind', $_allow_options)
    ensure_resource('tcpwrappers::allow', 'statd', $_allow_options)
  }
}
