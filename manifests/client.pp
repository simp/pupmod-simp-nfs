# @summary Manage configuration and services for a NFS client
#
# If using the `nfs::client::mount` define, this will be automatically called
# for you.
#
# @param blkmap
#   Whether to enable the `nfs-blkmap.service`
#
#   * Required for parallel NFS (pNFS).
#   * Only applicable for NFSv4.1 or later
#
# @param callback_port
#   The port used by the server to recall delegation of responsibilities to a
#   NFSv4 client.
#
#   * Only applicable in NFSv4.0.  Beginning with NFSv4.1, a separate callback
#     side channel is not required.
#
# @param stunnel
#   Enable `stunnel` connections from this client to each NFS server
#
#   * Stunnel can only be used for NFSv4 connections.
#   * Can be explicitly configured for each mount in `nfs::client::mount`.
#
# @param stunnel_socket_options
#   Additional stunnel socket options to be applied to each stunnel
#   connection to an NFS server
#
#   * Can be explicitly configured for each mount in `nfs::client::mount`.
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
#   * Can be explicitly configured for each mount in `nfs::client::mount`.
#
# @param stunnel_wantedby
#   The `systemd` targets that need `stunnel` to be active prior to being
#   activated
#
#   * Can be explicitly configured for each mount in `nfs::client::mount`.
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::client (
  Boolean          $blkmap                 = false,
  Simplib::Port    $callback_port          = 876,
  Boolean          $stunnel                = $nfs::stunnel,
  Array[String]    $stunnel_socket_options = $nfs::stunnel_socket_options,
  Integer[0]       $stunnel_verify         = $nfs::stunnel_verify,
  Array[String]    $stunnel_wantedby       = ['remote-fs-pre.target']
) inherits ::nfs {

  assert_private()

  include 'nfs::base::config'
  include 'nfs::base::service'
  include 'nfs::client::config'
  include 'nfs::client::service'

  Class['nfs::base::config'] ~> Class['nfs::base::service']
  Class['nfs::client::config'] ~> Class['nfs::client::service']
  Class['nfs::base::service'] ~> Class['nfs::client::service']

  if $nfs::kerberos {
    include 'krb5'

    Class['krb5'] ~> Class['nfs::client::service']

    if $nfs::keytab_on_puppet {
      include 'krb5::keytab'

      Class['krb5::keytab'] ~> Class['nfs::client::service']
    }
  }
}
