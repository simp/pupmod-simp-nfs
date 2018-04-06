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
# @author Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
#
define nfs::client::mount (
  Simplib::Host                             $nfs_server,
  Stdlib::Absolutepath                      $remote_path,
  Simplib::Port                             $port                 = 2049,
  Enum['nfs','nfs4']                        $nfs_version          = 'nfs4',
  Optional[Simplib::Port]                   $v4_remote_port       = undef,
  Enum['none','sys','krb5','krb5i','krb5p'] $sec                  = 'sys',
  String                                    $options              = 'hard,intr',
  Boolean                                   $at_boot              = true,
  Boolean                                   $autofs               = true,
  Boolean                                   $autofs_map_to_user   = false,
  Boolean                                   $stunnel_systemd_deps = true,
  Optional[Array[String]]                   $stunnel_wantedby     = undef
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

  if $stunnel_wantedby =~ Undef {
    $_stunnel_wantedby = $stunnel_wantedby
  }
  else {
    $_stunnel_wantedby = ['remote-fs-pre.target']
  }

  nfs::client::mount::connection { $name:
    nfs_server           => $nfs_server,
    nfs_version          => $nfs_version,
    nfs_port             => $port,
    v4_remote_port       => $v4_remote_port,
    stunnel_systemd_deps => $stunnel_systemd_deps,
    stunnel_wantedby     => $_stunnel_wantedby
  }

  if $nfs_version == 'nfs4' {
    $_nfs_options = "port=${port},${options},sec=${sec}"
  }
  else {
    $_nfs_options = "port=${port},${options}"
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

    if $::nfs::client::stunnel {
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

    if $::nfs::client::stunnel or $::nfs::client::is_server {
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
    if $::nfs::client::stunnel or $::nfs::client::is_server {
      mount { $name:
        ensure   => 'mounted',
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
        ensure   => 'mounted',
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
