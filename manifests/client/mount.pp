# @summary Set up a NFS client mount, optionally using autofs
#
# @param name
#   The local mount path
#
#   * When not using autofs (`$autofs` is `false`), this will be a static
#     mount and you must ensure the target directory exists.  This define will
#     **NOT** create the target directory for you.
#
#   * When using autofs (`$autofs` is `true`)
#
#     * autofs will create the target directory for you (full path).
#     * If `$autofs_indirect_map_key` is unset, a direct mount will be created
#       for this path.
#     * If `$autofs_indirect_map_key` is set, an indirect mount will be created:
#
#       * `$name` will be the mount point
#       * `$autofs_indirect_map_key` will be the map key
#
# @param nfs_server
#   The IP address of the NFS server to which you will be connecting
#
#   * If this host is also the NFS server, please set this to `127.0.0.1`.
#
# @param remote_path
#   The NFS share that you want to mount
#
# @param autodetect_remote
#   Attempts to figure out if this host is also the NFS server and adjust
#   the connection to the local IP address, `127.0.0.1`, in lieu of the
#   IP address specified in `$nfs_server`.
#
#   * When you know this host is also the NFS server, setting `$nfs_server`
#     to `127.0.0.1` is best.
#   * Auto-detect logic only works with IPv4 addresses.
#
# @param nfs_version
#   The NFS major version that you want to use.
#
#   * Used to set the `nfsvers` mount option
#   * If you need to specify an explicit minor version of NFSv4, include
#     'minorversion=<#>' in `$options`.
#
# @param sec
#   The security flavor for the mount
#
#   * Used to set the `sec` mount option for NFSv4 mounts
#   * Ignored for NFSv3 mounts
#
# @param options
#   String containing comma-separated list of additional mount options
#
#   * `fstype` will already be set for you
#   * If using stunnel with NFSv4, `proto` will be set to `tcp` for you
#
# @param ensure
#   The mount state of the specified mount point
#
#   * `mounted`   => Ensure that the mount point is actually mounted
#   * `present`   => Just add the entry to the fstab and do not mount it
#   * `unmounted` => Add the entry to the fstab and ensure that it is not
#                      mounted
#   * Has no effect if `$autofs` is `true`
#
# @param at_boot
#   Ensure that this mount is mounted at boot time
#
#   * Has no effect if `$autofs` is `true`
#
# @param autofs
#   Enable automounting with Autofs
#
# @param autofs_indirect_map_key
#   Autofs indirect map key
#
#   * May be '*', the wildcard map key
#
# @param autofs_add_key_subst
#   This enables map key substitution for a wildcard map key in an indirect map.
#
#   * Appends '/&' to the remote location.
#   * Only makes sense if `$autofs_indirect_map_key` is set to '*', the wildcard
#     map key.
#
# @param nfsd_port
#   The NFS server daemon listening port
#
#   * Used to set the `port` mount option
#   * If left unset, the value will be taken from `$nfs::nfsd`
#   * When using stunnel, must be a different value for each distinct
#     NFS server for which a stunneled mount connection is to be made.
#
# @param stunnel
#   Controls enabling `stunnel` to encrypt NFSv4 connection to the NFS server
#
#   * If left unset, the value will be taken from `$nfs::client::stunnel`
#   * May be set to `false` to ensure that `stunnel` will not be used for
#     this connection
#   * May be set to `true` to force the use of `stunnel` on this connection
#   * Unused when `$nfs_version` is 3.
#
#     * stunneled connections are not viable for NFSv3 because of the UDP-only
#       NFS client NSM notifications and the inability to effectively configure
#       the rpcbind port.
#     * If you know the NFS version negotiated with the NFS server will
#       fallback to NFSv3, you must set `$nfs_version` to 3 or `$stunnel` to
#       false. The mount will fail otherwise.
#
#   * Will *attempt* to determine if the host is trying to connect to itself
#     and use a direct, local connection in lieu of a stunnel in this case.
#
#     * When you know this host is also the NFS server, setting this to
#       `false` and `$nfs_server` to `127.0.0.1` is best.
#     * Auto-detect logic only works with IPv4 addresses.
#
# @param stunnel_nfsd_port
#   Listening port on the NFS server for the tunneled connection to
#   the NFS server daemon
#
#   * Decrypted traffic will be forwarded to `nfsd_port` on the NFS server
#   * If left unset, the value will be taken from `$nfs::stunnel_nfsd_port`
#   * Unused when `$stunnel` is `false`
#
# @param stunnel_socket_options
#   Additional stunnel socket options to be applied to the stunnel to the NFS
#   server
#
#   * If left unset, the value will be taken from
#     `$nfs::client::stunnel_socket_options`
#   * Unused when `$stunnel` is `false`
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
#   * If left unset, the value will be taken from
#     `$nfs::client::stunnel_socket_verify`
#   * Unused when `$stunnel` is `false`
#
# @param stunnel_wantedby
#   The `systemd` targets that need `stunnel` to be active prior to being
#   activated
#
#   * If left unset, the value will be taken from `$nfs::client::stunnel_wantedby`
#   * Unused when `$stunnel` is `false`
#
# @example Static mount
#  nfs::client::mount { '/mnt/apps1':
#    nfs_server  => '10.0.1.2',
#    remote_path => '/exports/apps1',
#    autofs      => false
#  }
#
# @example Direct automount
#  nfs::client::mount { '/mnt/apps2':
#    nfs_server  => '10.0.1.3',
#    remote_path => '/exports/apps2'
#  }
#
# @example Indirect automount with map key substitution
#  nfs::client::mount { '/home':
#    nfs_server              => '10.0.1.4',
#    remote_path             => '/exports/home',
#    autofs_indirect_map_key => '*',
#    autofs_add_key_subst    => true
#  }
#
# @example NFSv3 mount
#  nfs::client::mount { '/mnt/apps3':
#    nfs_server  => '10.0.1.5',
#    nfs_version => 3,
#    remote_path => '/exports/apps3',
#    autofs      => false
#  }
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
define nfs::client::mount (
  Simplib::Ip             $nfs_server,
  Stdlib::Absolutepath    $remote_path,
  Boolean                 $autodetect_remote       = true,
  Integer[3,4]            $nfs_version             = 4,
  Nfs::SecurityFlavor     $sec                     = 'sys',
  String                  $options                 = 'soft',
  Nfs::MountEnsure        $ensure                  = 'mounted',
  Boolean                 $at_boot                 = true,
  Boolean                 $autofs                  = true,
  Boolean                 $autofs_add_key_subst    = false,
  Optional[String[1]]     $autofs_indirect_map_key = undef,
  Optional[Simplib::Port] $nfsd_port               = undef,
  Optional[Boolean]       $stunnel                 = undef,
  Optional[Simplib::Port] $stunnel_nfsd_port       = undef,
  Optional[Array[String]] $stunnel_socket_options  = undef,
  Optional[Integer]       $stunnel_verify          = undef,
  Optional[Array[String]] $stunnel_wantedby        = undef
) {
  if ($name !~ Stdlib::Absolutepath) {
    fail('"$name" must be of type Stdlib::Absolutepath')
  }

  include 'nfs::client'

  if ($nfs_version == 3) and !$nfs::nfsv3 {
    fail('Cannot mount NFSv3 when NFSv3 is not enabled on client.  Set nfs::nfsv3 to true to fix.')
  }


  #############################################################
  # Pull in defaults from nfs and nfs::client classes as needed
  #############################################################
  if $nfsd_port !~ Undef {
    $_nfsd_port = $nfsd_port
  } else {
    $_nfsd_port = $nfs::nfsd_port
  }

  if $nfs_version == 3 {
    $_stunnel = false
  } elsif $stunnel !~ Undef {
    $_stunnel = $stunnel
  } else {
    $_stunnel = $nfs::client::stunnel
  }

  if $stunnel_nfsd_port !~ Undef {
    $_stunnel_nfsd_port = $stunnel_nfsd_port
  } else {
    $_stunnel_nfsd_port = $nfs::stunnel_nfsd_port
  }

  if $stunnel_socket_options !~ Undef {
    $_stunnel_socket_options = $stunnel_socket_options
  } else {
    $_stunnel_socket_options = $nfs::client::stunnel_socket_options
  }

  if $stunnel_verify !~ Undef {
    $_stunnel_verify = $stunnel_verify
  } else {
    $_stunnel_verify = $nfs::client::stunnel_verify
  }

  if $stunnel_wantedby !~ Undef {
    $_stunnel_wantedby = $stunnel_wantedby
  } else {
    $_stunnel_wantedby = $nfs::client::stunnel_wantedby
  }

  #################################
  # Configure connection and mount
  #################################

  if ($nfs_version  == 4) {
    $_nfs_base_options = "nfsvers=4,port=${_nfsd_port},${options},sec=${sec}"
  } else {
    $_nfs_base_options = "nfsvers=3,port=${_nfsd_port},${options}"
  }

  if $_stunnel {
    # stunnel only carries TCP
    $_nfs_options = "${_nfs_base_options},proto=tcp"
  } else {
    $_nfs_options = $_nfs_base_options
  }

  if $_stunnel or ($autodetect_remote and simplib::host_is_me($nfs_server)) {
    $_remote = "127.0.0.1:${remote_path}"
  } else {
    $_remote = "${nfs_server}:${remote_path}"
  }

  nfs::client::mount::connection { $name:
    nfs_server             => $nfs_server,
    nfs_version            => $nfs_version,
    nfsd_port              => $_nfsd_port,
    firewall               => $nfs::firewall,
    stunnel                => $_stunnel,
    stunnel_nfsd_port      => $_stunnel_nfsd_port,
    stunnel_socket_options => $_stunnel_socket_options,
    stunnel_verify         => $_stunnel_verify,
    stunnel_wantedby       => $_stunnel_wantedby,
    tcpwrappers            => $nfs::tcpwrappers
  }

  if $autofs {
    simplib::assert_optional_dependency($module_name, 'simp/autofs')
    include 'autofs'

    Class['nfs::install'] -> Class['autofs::install']

    if $autofs_indirect_map_key {
      $_mount_point = $name
      if $autofs_indirect_map_key == '*' {
        $_map_key = "wildcard-${name}"
      } else {
        $_map_key = $autofs_indirect_map_key
      }
    } else {
      $_mount_point = '/-'
      $_map_key = $name
    }

    # The map name is very particular
    $_clean_name = regsubst( regsubst($name, '^/', ''), '/', '__', 'G' )
    $_map_name = sprintf('/etc/autofs/%s.map', $_clean_name)

    autofs::map::master { $name:
      mount_point => $_mount_point,
      map_name    => $_map_name,
      require     => Nfs::Client::Mount::Connection[$name]
    }

    if $autofs_add_key_subst {
      $_location = "${_remote}/&"
    } else {
      $_location = $_remote
    }

    autofs::map::entry { $_map_key:
      options  => "-${_nfs_options}",
      location => $_location,
      target   => $_clean_name,
      require  => Nfs::Client::Mount::Connection[$name]
    }

    if $_stunnel {
      # This is a workaround for issues with hooking into stunnel
      $_exec_attributes = {
        command     => '/usr/bin/systemctl reload autofs',
        refreshonly => true,
        require     => Class['autofs::service']
      }

      ensure_resource( 'exec', 'reload_autofs', $_exec_attributes)

      # This is so that the automounter gets reloaded when *any* of the
      # related stunnel instances are refreshed
      Stunnel::Instance <| tag == 'nfs' |> ~> Exec['reload_autofs']
    }

  } else {
    mount { $name:
      ensure   => $ensure,
      atboot   => $at_boot,
      device   => $_remote,
      fstype   => 'nfs', # EL>6 NFS version specified in options not fstype
      options  => $_nfs_options,
      remounts => false,
      require  => Nfs::Client::Mount::Connection[$name]
    }
  }
}
