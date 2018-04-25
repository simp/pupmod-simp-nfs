# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# A helper for setting up the cross-system connectivity parts of a mount
#
# **This should NOT be called from outside ``nfs::client::mount``**
#
# All parameters map to their counterparts in ``nfs::client::mount``
#
# @param nfs_server
# @param nfs_version
# @param nfs_port
# @param v4_remote_port
# @param stunnel
# @param stunnel_systemd_deps
# @param stunnel_wantedby
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
define nfs::client::mount::connection (
  Simplib::Host           $nfs_server,
  Enum['nfs','nfs4']      $nfs_version,
  Simplib::Port           $nfs_port             = 2049,
  Optional[Simplib::Port] $v4_remote_port       = undef,
  Optional[Boolean]       $stunnel              = undef,
  Boolean                 $stunnel_systemd_deps = true,
  Array[String]           $stunnel_wantedby     = []
) {

  # This is only meant to be called from inside nfs::client::mount
  assert_private()

  # Take our best shot at getting this right...
  # If this doesn't work, you'll need to set ``stunnel`` to ``false`` in your
  # call to ``nfs::client::mount``
  if $stunnel {
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
          nfs_connect_port     => $v4_remote_port,
          stunnel_systemd_deps => $stunnel_systemd_deps,
          stunnel_wantedby     => $stunnel_wantedby,
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
