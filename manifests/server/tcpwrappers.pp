# @summary Configure TCP wrappers for NFS server services
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::server::tcpwrappers
{
  assert_private()

  # TCP wrappers was dropped in EL8
  if (versioncmp($facts['os']['release']['major'], '8') < 0) {
    include 'tcpwrappers'

    # On EL7, the following NFS-server-related executables are dynamically
    # linked to libwrap:
    # * rpc.rquotad; man page says TCP wrappers service name 'rquotad'
    # * rpc.statd; man page says TCP wrappers under daemon name 'statd'
    # * rpc.mountd; man page says TCP wrappers under daemon name 'mountd'
    # * exportfs; not a daemon so not appropriate
    # * rpcbind
    #
    # stunnel also uses TCP wrappers with a service name that matches the
    # tunnel's service name. The tcpwrappers::allow is handled by the stunnel
    # module.

    $_allow_options = { pattern => $nfs::trusted_nets }

    # Resource in common with nfs::client, which may be on this node.
    ensure_resource('tcpwrappers::allow', 'rpcbind', $_allow_options)

    if $nfs::server::nfsd_vers3 {
      # Resource in common with nfs::client, which may be on this node.
      ensure_resource('tcpwrappers::allow', 'statd', $_allow_options)

      $_allow = [ 'mountd', 'rquotad' ]
    } else {
      $_allow = ['rquotad']
    }

    tcpwrappers::allow { $_allow:
      pattern => $nfs::server::trusted_nets
    }
  }
}
