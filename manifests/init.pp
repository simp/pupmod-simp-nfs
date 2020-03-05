# @summary Provides the base configuration and services for an NFS server and/or client.
#
# @param is_server
#   Explicitly state that this system should be an NFS server
#
#   * Further configuration can be made via the `nfs::server` class
#
# @param is_client
#   Explicitly state that this system should be an NFS client
#
#   * Further configuration can be be made via the `nfs::client` class
#
# @param nfsv3
#   Allow use of NFSv3.  When false, only NFSv4 will be allowed.
#
# @param gssd_avoid_dns
#   Use a reverse DNS lookup, even if the server name looks like a canonical name
#
#   * Sets the `avoid-dns` option in the `gssd` section of `/etc/nfs.conf`
#
# @param gssd_limit_to_legacy_enctypes
#   Restrict sessions to weak encryption types
#
#   * Sets the `limit-to-legacy-enctypes` option in the `gssd` section of
#     `/etc/nfs.conf`
#
# @param gssd_use_gss_proxy
#   Use the gssproxy daemon to hold the credentials used in secure NFS and
#   perform GSSAPI operations on behalf of NFS.
#
#   * Sets the `use-gss-proxy` option in the `gssd` section of `/etc/nfs.conf`
#     This is not yet documented in the rpc.gssd man page for EL8, but is
#     available in the example `/etc/nsf.conf file` packaged with `nfs-utils`.
#   * Sets GSS_USE_PROXY in `/etc/sysconfig/nfs` in EL7, because the
#     `use-gss-proxy` option in `/etc/nfs.conf` is not yet used in EL7.
#
# @param lockd_port
#   The TCP port upon which `lockd` should listen on both the NFS server and
#   the NFS client (NFSv3)
#
#   * Sets the `port` option in the `lockd` section of `/etc/nfs.conf`
#   * Corresponds to the `nlockmgr` service TCP port reported by `rpcinfo`
#
# @param lockd_udp_port
#   The UDP port upon which `lockd` should listen on both the NFS server and
#   the NFS client (NFSv3)
#
#   * Sets the `udp-port` option in the `lockd` section of `/etc/nfs.conf`
#   * Corresponds to the `nlockmgr` service UDP port reported by `rpcinfo`
#
# @param nfsd_port
#   The port upon which NFS daemon on the NFS server should listen
#
#   * Sets the `port` option in the `nfsd` section of `/etc/nfs.conf`
#   * Corresponds to the `nfs` and `nfs_acl` service ports reported by
#     `rpcinfo`
#
# @param sm_notify_outgoing_port
#   The port that `sm-notify` will use when notifying NFSv3 peers
#
#   * Sets the `outgoing-port` option in the `sm-notify` section of
#     `/etc/nfs.conf`
#
# @param statd_port
#   The port upon which `statd` should listen on both the NFS server
#   and the NFS client (NFSv3)
#
#   * Sets the `port` option in the `statd` section of `/etc/nfs.conf`
#   * Corresponds to the `status` service port reported by `rpcinfo`
#
# @param statd_outgoing_port
#   The port that `statd` will use when communicating with NFSv3 peers
#
#   * Sets the `outgoing-port` option in the `status` section of
#     `/etc/nfs.conf`
#
# @param custom_nfs_conf_opts
#   Hash that allows other configuration options to be set in `/etc/nfs.conf`
#
#   * Each key is a known section of `/etc/nfs.conf`, such as `nfsd`.
#   * Each value is a Hash of config parameter names and values.
#   * Configuration values are not validated.
#   * If a new section needs to be added to `/etc/nfs.conf`, you can use
#     `concat::fragment`.
#
#   @example Set NFS server's grace and lease times in Hiera
#     nfs::custom_nfs_conf_opts:
#       nfsd:
#         grace-time: 60
#         lease-time: 60
#
# @param custom_daemon_args
#   Hash that allows other configuration options to be set as daemon
#   arguments in `/etc/sysconfig/nfs` in EL7
#
#   * Necessary to address `/etc/nfs.conf` limitations - Not all configuration
#     options in EL7 can be specified in `/etc/nfs.conf`
#   * Each key is the name of the shell variables processed by
#     `/usr/lib/systemd/scripts/nfs-utils_env.sh`
#
#     * `nfs-utils_env.sh` generates `/run/sysconfig/nfs-utils` which contains
#       the NFS daemon command line shell variables used by NFS services
#     * Unfortunately, not all shell variable names in `/etc/sysconfig/nfs`
#       match the generated variable names in `/run/sysconfig/nfs-utils`.
#       For example, `STATDARG` gets transformed into `STATDARGS`.
#
#   * Each value is the argument string which will be wrapped in double
#     quotes in `/etc/sysconfig/nfs`.
#
#   @example Disable syslog messages from the NFSv3 `rpc.statd` daemon in Hiera
#     nfs::custom_daemon_args:
#       STATDARG: "--no-syslog"
#
# @param idmapd
#   Whether to use `idmapd` for NFSv4 ID to name mapping
#
# @param secure_nfs
#   Whether to enable secure NFS mounts
#
# @param sunrpc_udp_slot_table_entries
#   Set the default UDP slot table entries in the kernel
#
#   * Most NFS performance guides seem to recommend this setting
#   * If you have a low memory system, you may want to reduce this
#
# @param sunrpc_tcp_slot_table_entries
#   Set the default TCP slot table entries in the kernel
#
#   * Most NFS performance guides seem to recommend this setting
#   * If you have a low memory system, you may want to reduce this
#
# @param ensure_latest_lvm2
#   See `nfs::lvm2` for further description
#
# @param kerberos
#   Use the SIMP `krb5` module for Kerberos support
#
#   * You may need to set variables in `krb5::config` via Hiera or your ENC
#     if you do not like the defaults.
#
# @param keytab_on_puppet
#   Whether the NFS server will pull its keytab directly from the Puppet server
#
#   * Only applicable if `$kerberos` is `true.
#   * If `false`, you will need to ensure the appropriate services are restarted
#     and cached credentials are destroyed (e.g., gssproxy cache), when the keytab
#     is changed.
#
# @param firewall
#   Use the SIMP `iptables` module to manage firewall connections
#
# @param tcpwrappers
#   Use the SIMP `tcpwrappers` module to manage TCP wrappers
#
# @param stunnel
#   Wrap `stunnel` around critical NFSv4 connections
#
#   * This is intended for environments without a working Kerberos setup
#     and may cause issues when used with Kerberos.
#   * Use of Kerberos is preferred.
#   * This will configure the NFS server and client mount to only use
#     TCP communication
#   * Cannot be used for NFSv4.0 connections, because NFSv4.0 uses a side
#     channel to each NFS client to recall delegation responsibilities.
#   * The following connections will not be secured, due to tunneling
#     limitations in deployments using multiple NFS servers
#
#     - Connections to the rbcbind service
#     - Connections to the rpc-rquotad service
#
#   * Use of stunnel for an individual client mount can be controlled
#     by the `stunnel` parameter in the `nfs::client::mount` define.
#   * Use of stunnel for just the NFS server on this host can be controlled
#     by the `stunnel` parameter in the `nfs::server` class.
#
# @param stunnel_nfsd_port
#   Listening port on the NFS server for the tunneled connection to
#   the NFS server daemon
#
#   * Decrypted traffic will be forwarded to `$nfsd_port` on the NFS server
#
# @param stunnel_socket_options
#   Additional socket options to set for all stunnel connections
#
#   * Stunnel socket options for an individual client mount can be controlled
#     by the `stunnel_socket_options` parameter in the `nfs::client::mount`
#     define.
#   * Stunnel socket options for just the NFS server on this host can be
#     controlled by the `stunnel_socket_options` parameter in the
#     `nfs::server` class.
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
#   * Stunnel verify for an individual client mount can be controlled
#     by the `stunnel_verify` parameter in the `nfs::client::mount` define.
#   * Stunnel verify for just the NFS server on this host can be controlled
#     by the `stunnel_verify` parameter in the `nfs::server` class.
#
# @param tcpwrappers
#   Use the SIMP `tcpwrappers` module to manage TCP wrappers
#
# @param trusted_nets
#   The systems that are allowed to connect to this service
#
#   * Set to 'any' or 'ALL' to allow the world
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs (
  Boolean               $is_server                     = false,
  Boolean               $is_client                     = true,
  Boolean               $nfsv3                         = false,
  Boolean               $gssd_avoid_dns                = true,
  Boolean               $gssd_limit_to_legacy_enctypes = false,
  Boolean               $gssd_use_gss_proxy            = true,
  Simplib::Port         $lockd_port                    = 32803,
  Simplib::Port         $lockd_udp_port                = 32769,
  Simplib::Port         $nfsd_port                     = 2049,
  Simplib::Port         $sm_notify_outgoing_port       = 2021,
  Simplib::Port         $statd_port                    = 662,
  Simplib::Port         $statd_outgoing_port           = 2020,
  Nfs::NfsConfHash      $custom_nfs_conf_opts          = {},
  Nfs::LegacyDaemonArgs $custom_daemon_args            = {},
  Boolean               $idmapd                        = false,
  Boolean               $secure_nfs                    = false,
  Integer[1]            $sunrpc_udp_slot_table_entries = 128,
  Integer[1]            $sunrpc_tcp_slot_table_entries = 128,
  Boolean               $ensure_latest_lvm2            = true,
  Boolean               $kerberos                      = simplib::lookup('simp_options::kerberos', { 'default_value' => false }),
  Boolean               $keytab_on_puppet              = simplib::lookup('simp_options::kerberos', { 'default_value' => true}),
  Boolean               $firewall                      = simplib::lookup('simp_options::firewall', { 'default_value' => false}),
  Boolean               $stunnel                       = simplib::lookup('simp_options::stunnel', { 'default_value' => false }),
  Simplib::Port         $stunnel_nfsd_port             = 20490,
  Array[String]         $stunnel_socket_options        = ['l:TCP_NODELAY=1','r:TCP_NODELAY=1'],
  Integer               $stunnel_verify                = 2,
  Boolean               $tcpwrappers                   = simplib::lookup('simp_options::tcpwrappers', { 'default_value' => false }),
  Simplib::Netlist      $trusted_nets                  = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1'] })
) {

  simplib::assert_metadata($module_name)
  if (versioncmp($facts['os']['release']['full'], '7.4') < 0) {
    warning("This version of simp-nfs may not work with ${facts['os']['name']} ${facts['os']['release']['full']}. Use simp-nfs module version < 7.0.0 instead")
  }

  if $firewall {
    simplib::assert_optional_dependency($module_name, 'simp/iptables')
  }

  if $kerberos {
    simplib::assert_optional_dependency($module_name, 'simp/krb5')
  }

  if $tcpwrappers and (versioncmp($facts['os']['release']['major'], '8') < 0) {
    simplib::assert_optional_dependency($module_name, 'simp/tcpwrappers')
  }

  include 'nfs::install'

  if $kerberos and (versioncmp($facts['os']['release']['major'], '8') < 0) {
    # This is here because the SELinux rules for directory includes in krb5
    # are broken in selinux-policy < 3.13.1-229.el7_6.9. It does no harm
    # on an EL7 system with the fixed selinux-policy.
    include 'nfs::selinux_hotfix'
    Class['nfs::selinux_hotfix'] -> Class['nfs::install']
  }

  if $ensure_latest_lvm2 {
    # TODO Figure out if this is still needed.
    include 'nfs::lvm2'
    Class['nfs::lvm2'] -> Class['nfs::install']
  }

  if $is_client {
    include 'nfs::client'
    Class['nfs::install'] -> Class['nfs::client']
  }

  if $is_server {
    include 'nfs::server'
    Class['nfs::install'] -> Class['nfs::server']
  }
}
