# Set up a NFS client to point to be mounted, optionally using autofs
#
# @param name [Variant[Stdlib::Absolutepath, Pattern['^wildcard-']]
#   The local path to be mounted
#
#   * This can also be ``wildcard-<some_unique_string>`` if ``autofs`` is
#     ``true``. This will create a wildcard autofs entry (``*``) for your
#     mount.
#   * **NOTE:** This define will **NOT** create the target file for you
#
# @param nfs_server
#   The NFS server to which you will be connecting
#
#   * If you are the server, please make sure that this is ``127.0.0.1``
#
# @param remote_path
#   The NFS share that you want to mount
#
# @param autodetect_remote
#   This should be set to ``false`` if you want to ignore any 'intelligent'
#   guessing as to whether or not your system is the NFS server.
#
#   For instance, if you are an NFS server, but want to mount an NFS share on a
#   remote system, then you will need to set this to ``false`` to ensure that
#   your mount is not set to ``127.0.0.1`` based on the detection that you are
#   also an NFS server.
#
# @param port
#   The NFS port to which to connect
#
# @param nfs_version
#   The NFS version that you want to use
#
# @param v4_remote_port
#   If using NFSv4, specify the remote port to which to connect
#
# @param sec
#   The sec mode for the mount
#
#   * Only valid with NFSv4
#
# @param options
#   The mount options string that should be used
#
#   * fstype and port will already be set for you
#
# @param ensure
#   The mount state of the specified mount point
#
#   * ``mounted``   => Ensure that the mount point is actually mounted
#   * ``present``   => Just add the entry to the fstab and do not mount it
#   * ``unmounted`` => Add the entry to the fstab and ensure that it is not
#                      mounted
#   * Has no effect if ``$autofs`` is set
#
# @param at_boot
#   Ensure that this mount is mounted at boot time
#
#   * Has no effect if ``$autofs`` is set
#
# @param autofs
#   Enable automounting with Autofs
#
#
# @param autofs_map_to_user
#   Ensure that autofs maps automatically map to a directory that matches the
#   username of the logged in user
#
#   * If you are appending your own special maps, make sure this is not set
#
# @param stunnel
#   Controls enabling ``stunnel`` for this connection
#
#   * If left unset, the value will be taken from ``nfs::client::stunnel``
#   * May be set to ``false`` to ensure that ``stunnel`` will not be used for
#     this connection
#   * May be set to ``true`` to force the use of ``stunnel`` on this connection
#
# @param stunnel_systemd_deps
#   Add the appropriate ``systemd`` dependencies on systems that use ``systemd``
#
# @param stunnel_wantedby
#   The ``systemd`` targets that need ``stunnel`` to be active prior to being
#   activated
#
# @author Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
#
define nfs::client::mount (
  Simplib::Host                         $nfs_server,
  Stdlib::Absolutepath                  $remote_path,
  Boolean                               $autodetect_remote    = true,
  Simplib::Port                         $port                 = 2049,
  Enum['nfs','nfs4']                    $nfs_version          = 'nfs4',
  Optional[Simplib::Port]               $v4_remote_port       = undef,
  Nfs::SecurityFlavor                   $sec                  = 'sys',
  String                                $options              = 'hard,intr',
  Enum['mounted','present','unmounted'] $ensure               = 'mounted',
  Boolean                               $at_boot              = true,
  Boolean                               $autofs               = true,
  Boolean                               $autofs_map_to_user   = false,
  Optional[Boolean]                     $stunnel              = undef,
  Boolean                               $stunnel_systemd_deps = true,
  Array[String]                         $stunnel_wantedby     = ['remote-fs-pre.target']
) {
  if $autofs {
    if ($name !~ Stdlib::Absolutepath) and ($name !~ Pattern['^wildcard-']) {
      fail('"$name" must be of type Stdlib::Absolutepath or Pattern["^wildcard-"]')
    }
  }
  elsif ($name !~ Stdlib::Absolutepath) {
    fail('"$name" must be of type Stdlib::Absolutepath')
  }

  $_clean_name = regsubst(
    regsubst(
      regsubst($name,'wildcard-',''),'^/',''
    ),'/', '__', 'G'
  )

  include '::nfs::client'

  if $nfs_version == 'nfs4' {
    $_nfs_options = "port=${port},${options},sec=${sec}"
  }
  else {
    $_nfs_options = "port=${port},${options}"
  }

  if $stunnel !~ Undef {
    $_stunnel = $stunnel
  }
  else {
    $_stunnel = $nfs::client::stunnel
  }

  nfs::client::mount::connection { $name:
    nfs_server           => $nfs_server,
    nfs_version          => $nfs_version,
    nfs_port             => $port,
    v4_remote_port       => $v4_remote_port,
    stunnel              => $_stunnel,
    stunnel_systemd_deps => $stunnel_systemd_deps,
    stunnel_wantedby     => $stunnel_wantedby
  }

  if $autofs {
    include '::autofs'

    Class['nfs::install'] -> Class['::autofs::install']

    # This is a particular quirk about the autofs service ordering
    Class['autofs::service'] ~> Service[$::nfs::service_names::rpcbind]

    # Need to handle the wildcard cases
    $_mount_point = split($name,'wildcard-')[-1]

    # The map name is very particular
    $_map_name = sprintf('/etc/autofs/%s.map', $_clean_name)

    autofs::map::master { $name:
      mount_point => $_mount_point,
      map_name    => $_map_name,
      require     => Nfs::Client::Mount::Connection[$name]
    }

    if $_stunnel {
      # This is a workaround for issues with hooking into stunnel
      exec { 'refresh_autofs':
        command     => '/usr/bin/pkill -HUP -x automount',
        refreshonly => true,
        require     => Class['autofs::service']
      }

      # This is so that the automounter gets refreshed when *any* of the
      # related stunnel instances are refreshed
      Stunnel::Instance <| tag == 'nfs' |> ~> Exec['refresh_autofs']
    }

    if $_stunnel or ($autodetect_remote and $::nfs::client::is_server) {
      if $autofs_map_to_user {
        $_location = "127.0.0.1:${remote_path}/&"
      }
      else {
        $_location = "127.0.0.1:${remote_path}"
      }

      autofs::map::entry { $name:
        options  => "-fstype=${nfs_version},${_nfs_options}",
        location => $_location,
        target   => $_clean_name,
        require  => Nfs::Client::Mount::Connection[$name]
      }
    }
    else {
      if $autofs_map_to_user {
        $_location = "${nfs_server}:${remote_path}/&"
      }
      else {
        $_location = "${nfs_server}:${remote_path}"
      }
      autofs::map::entry { $name:
        options  => "-fstype=${nfs_version},${_nfs_options}",
        location => $_location,
        target   => $_clean_name,
        require  => Nfs::Client::Mount::Connection[$name]
      }
    }
  }
  else {
    if $_stunnel or ($autodetect_remote and $::nfs::client::is_server) {
      mount { $name:
        ensure   => $ensure,
        atboot   => $at_boot,
        device   => "127.0.0.1:${remote_path}",
        fstype   => $nfs_version,
        options  => $_nfs_options,
        remounts => false,
        require  => Nfs::Client::Mount::Connection[$name]
      }
    }
    else {
      mount { $name:
        ensure   => $ensure,
        atboot   => $at_boot,
        device   => "${nfs_server}:${remote_path}",
        fstype   => $nfs_version,
        options  => $_nfs_options,
        remounts => false,
        require  => Nfs::Client::Mount::Connection[$name]
      }
    }
  }
}
