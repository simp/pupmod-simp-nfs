# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# A helper for setting up the cross-system connectivity parts of a mount
#
# @param nfs_server
#   The NFS server to which you will be connecting
#
#   * If you are the server, please make sure that this is ``127.0.0.1``
#
# @param nfs_version
#   The NFS version that you want to use
#
# @param port
#   The NFS port to which to connect
#
#
# @param v4_remote_port
#   If using NFSv4, the remote port to which to connect
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
define nfs::client::mount::connection (
  Simplib::Host           $nfs_server,
  Enum['nfs','nfs4']      $nfs_version,
  Simplib::Port           $nfs_port       = 2049,
  Optional[Simplib::Port] $v4_remote_port = undef
) {
  assert_private()

  include '::nfs::client'

  # Take our best shot at getting this right...
  # If this doesn't work, you'll need to disable ``nfs::client::stunnel`` for
  # this host explicitly
  if $::nfs::client::stunnel and !host_is_me($nfs_server) {
    if $nfs_version == 'nfs' {
      # This is not great but the target is actually only able to be called
      # once anyway
      ensure_resource('class',
        'nfs::client::stunnel',
        {
          nfs_server => $nfs_server
        }
      )
    }
    else {
      # It is possible that this is called for multiple mounts on the same server
      ensure_resource('nfs::client::stunnel::v4',
        "${nfs_server}:${nfs_port}",
        {
          nfs_connect_port => $v4_remote_port
        }
      )
    }
  }

  # Set up the callback port IPTables opening if appropriate
  if $::nfs::client::firewall {
    include '::iptables'

    # It is possible that this is called for multiple mounts on the same server
    ensure_resource('iptables::listen::tcp_stateful',
      "nfs_callback_${nfs_server}",
      {
        trusted_nets => [$nfs_server],
        dports       => $nfs::client::callback_port
      }
    )
  }
}
