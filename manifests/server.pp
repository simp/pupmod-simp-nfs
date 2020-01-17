# @summary Manage configuration and services for a NFS server
#
# If using the `nfs::server::export` define, this will be automatically called
# for you.
#
# @param nfsd_vers3
#   Allow use of NFSv3
#
#   * Sets the `vers3` option in the `nfsd` section of `/etc/nfs.conf`
#   * Set this to `false` when `$nfs::nfsv3` is `true`, `$nfs::is_client` is
#     `true`, and you want the NFS client on this host to be able to create
#     NFSv3 mounts from other hosts, but do **not** want other hosts to be able
#     create NFSv3 mounts of filesystems exported by this host's NFS server.
#     Otherwise, it should remain at the default value.
#
# @param nfsd_vers4
#   Allow use of NFSv4
#
#   * Sets the `vers4` option in the `nfsd` section of `/etc/nfs.conf`
#
# @param nfsd_vers4_0
#   Allow use of NFSv4.0
#
#   * NFSv4.0 uses a side channel to the NFS client to recall delegation
#     responsibilities.  When this is used, all communications cannot be
#     encrypted with `stunnel`.
#   * Sets the `vers4.0` option in the `nfsd` section of `/etc/nfs.conf`
#
# @param nfsd_vers4_1
#   Allow use of NFSv4.1
#
#   * Sets the `vers4.1` option in the `nfsd` section of `/etc/nfs.conf`
#
# @param nfsd_vers4_2
#   Allow use of NFSv4.2
#
#   * Sets the `vers4.2` option in the `nfsd` section of `/etc/nfs.conf`
#   * NFSv4.2 is available beginning with EL8, so this setting will be
#     ignored in EL7.
#
# @param mountd_port
#   The port upon which `mountd` should listen on the server (NFSv3)
#
#   * Sets the `port` option in the `mountd` section of `/etc/nfs.conf`
#   * Corresponds to the `mountd` service port reported by `rpcinfo`
#
# @param nfsd_port
#   The port upon which NFS daemon on the NFS server should listen
#
#   * Sets the `port` option in the `nfsd` section of `/etc/nfs.conf`
#   * Corresponds to the `nfs` and `nfs_acl` service ports reported by
#     `rpcinfo`
#
# @param rquotad_port
#   The port upon which `rquotad` on the NFS server should listen
#
#   * Sets the port command line option in `RPCRQUOTADOPTS` in
#     `/etc/sysconfig/rpc-rquotad`
#   * Corresponds to the `rquotad` service port reported by `rpcinfo`
#
# @param custom_rpcrquotad_opts
#   * Additional arguments to pass to the `rpc.rquotad` daemon
#
# @param sunrpc_udp_slot_table_entries
#   Set the default UDP slot table entries in the kernel
#
#   * Most NFS server performance guides seem to recommend this setting
#   * If you have a low memory system, you may want to reduce this
#
# @param sunrpc_tcp_slot_table_entries
#   Set the default TCP slot table entries in the kernel
#
#   * Most NFS server performance guides seem to recommend this setting
#   * If you have a low memory system, you may want to reduce this
#
# @param stunnel
#   Controls enabling `stunnel` to encrypt critical NFSv4 connections
#
#   * This will configure the NFS server to only use TCP communication
#   * This cannot be effectively used with NFSv4.0 connections because of the
#     delegation side channel to the NFS client.
#
# @param stunnel_accept_address
#   The address upon which the NFS server will listen for stunnel connections
#
#   * You should be set this to `0.0.0.0` for all interfaces
#   * Unused when `$stunnel` is `false`
#
# @param stunnel_nfsd_accept_port
#   Listening port on the NFS server for the tunneled connection to
#   the NFS server daemon
#
#   * Decrypted traffic will be forwarded to `nfsd_port` on the NFS server
#     daemon.
#   * Unused when `$stunnel` is `false`
#
# @param stunnel_socket_options
#   Additional socket options to set for stunnel connections
#
#   * Unused when `$stunnel` is `false`
#
# @param stunnel_verify
#   The level at which to verify TLS connections from clients
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
# @param trusted_nets
#   The systems that are allowed to connect to this service
#
#   * Set to 'any' or 'ALL' to allow the world
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::server (
  Boolean          $nfsd_vers3                    = $nfs::nfsv3,
  Boolean          $nfsd_vers4                    = true,
  Boolean          $nfsd_vers4_0                  = false,
  Boolean          $nfsd_vers4_1                  = true,
  Boolean          $nfsd_vers4_2                  = true,
  Simplib::Port    $mountd_port                   = 20048,
  Simplib::Port    $nfsd_port                     = $nfs::nfsd_port,
  Simplib::Port    $rquotad_port                  = 875,
  Optional[String] $custom_rpcrquotad_opts        = undef,
  Integer[1]       $sunrpc_udp_slot_table_entries = 128,
  Integer[1]       $sunrpc_tcp_slot_table_entries = 128,
  Boolean          $stunnel                       = $nfs::stunnel,
  Simplib::IP      $stunnel_accept_address        = '0.0.0.0',
  Simplib::Port    $stunnel_nfsd_accept_port      = $nfs::stunnel_nfsd_port,
  Array[String]    $stunnel_socket_options        = $nfs::stunnel_socket_options,
  Integer          $stunnel_verify                = $nfs::stunnel_verify,
  Array[String]    $stunnel_wantedby              = [ 'nfs-server.service' ],
  Simplib::Netlist $trusted_nets                  = $nfs::trusted_nets
) inherits ::nfs {

  assert_private()

  if $stunnel and $nfsd_vers4_0 {
    fail('NFSv4.0 within stunnel is unsupported. Set nfs::server::nfsd_vers4_0 or nfs::server::stunnel to false to fix.')
  }

  include 'nfs::base::config'
  include 'nfs::base::service'
  include 'nfs::server::config'
  include 'nfs::server::service'

  Class['nfs::base::config'] ~> Class['nfs::base::service']
  Class['nfs::server::config'] ~> Class['nfs::server::service']
  Class['nfs::base::service'] ~> Class['nfs::server::service']

  include 'nfs::idmapd::server'

  if $nfs::server::stunnel {
    include 'nfs::server::stunnel'
    Class['nfs::server::stunnel'] ~> Class['nfs::server::service']
  }

  if $nfs::firewall {
    include 'nfs::server::firewall'
  }

  if $nfs::kerberos {
    include 'krb5'

    Class['krb5'] ~> Class['nfs::server::service']

    if $nfs::keytab_on_puppet {
      include 'krb5::keytab'

      Class['krb5::keytab'] ~> Class['nfs::server::service']
    }
  }
}
