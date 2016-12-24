# Define Type to set up the ``/etc/exports`` file
#
# @see exports(5)
#
# Be careful! The name of these mounts must be unique, but the only unique
# combination is mountpoint + client.  Therefore, you can actually have
# duplicate entries.
#
# NFS will function fine with this but the **last** duplicate entry in the file
# will win!
#
# @param export_path
#   The path on the filesystem to export
#
# @param clients
#   NFS export-compatible clients to which the export should be served.
#
#   * The entry will be repeated for each client
#
# @param comment
#   A comment to be added to the entry
#
# @param insecure
#   Do not require that requests originate on a Port less than ``1024``
#
# @param rw
#   Allow both reads and writes on this volume
#
# @param async
#   Allow the NFS server to reply to request before changes have been committed
#   to stable storage
#
# @param no_wdelay
#   Disable write delays
#
#   * Has no effect if ``$async`` is set
#
# @param nohide
#   Disable hiding of subordinate filesystems
#
# @param crossmnt
#   Allow clients to access all filesystems mounted on a filesystem marked with
#   ``crossmnt``
#
# @param subtree_check
#   Enable subtree checking
#
# @param insecure_locks
#   Do not require authentication of locking requests
#
# @param mountpoint
#   Require this path to be successfully mounted on disk
#
#   * If a ``Boolean``, require the export path to be successfully mounted
#
# @param fsid
#   A specific ID for the exported filesystem
#
# @param nordirplus
#   Disable ``READDIRPLUS`` request handling on ``NFSv3`` clients
#
# @param refer
#   A list of alternate locations for the filesystem
#
#   * This should be in the form specified by the man page:
#     ``path@host[+host]``
#
#   * There will be **minimal** validation and they will be joined by ``:``
#
# @param sec
#   Security flavors, in order of preference
#
# @param no_root_squash
#   Disable root squashing
#
#   * This should only be done if you *really* know what you are doing!
#
# @param all_squash
#   Map all uids and gids to the ``anonymous`` user
#
# @param anonuid
#   Explicity set the ``UID`` of the ``anonymous`` user
#
# @param anongid
#   Explicity set the ``GID`` of the ``anonymous`` user

# @param custom
#   A custom set of options
#
#   * If set, all other options will be ignored
#   * ``$mountpoint`` and ``$client`` must still be set
#   * Do *not* include the parenthesis if you are writing a custom options
#     string.
#
# @author Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
#
define nfs::server::export (
  Stdlib::Absolutepath                             $export_path,
  Array[String]                                    $clients,
  Optional[String]                                 $comment        = undef,
  Boolean                                          $insecure       = false,
  Boolean                                          $rw             = false,
  Boolean                                          $async          = false,
  Boolean                                          $no_wdelay      = false,
  Boolean                                          $nohide         = false,
  Boolean                                          $crossmnt       = false,
  Boolean                                          $subtree_check  = false,
  Boolean                                          $insecure_locks = false,
  Optional[Variant[
    Stdlib::Absolutepath,
    Boolean
  ]]                                               $mountpoint     = undef,
  Optional[String]                                 $fsid           = undef,
  Boolean                                          $nordirplus     = false,
  Optional[Array[Pattern['^/.+@.+$']]]             $refer          = undef,
  Array[Enum['none','sys','krb5','krb5i','krb5p']] $sec            = ['sys'],
  Boolean                                          $no_root_squash = false,
  Boolean                                          $all_squash     = false,
  Simplib::Port                                    $anonuid        = 65534,
  Simplib::Port                                    $anongid        = 65534,
  Optional[String]                                 $custom         = undef
) {
  include '::nfs::server'

  $_name = inline_template('<%= @name.gsub("/","|") -%>')

  concat::fragment { "nfs_${_name}_export":
    target  => '/etc/exports',
    content => template("${module_name}/server/export.erb")
  }

  # We have to do this if we have a 'sec=sys' situation on EL7+
  if 'sys' in $sec {
    if $facts['os']['family']== 'RedHat' {
      if $facts['os']['name'] in ['RedHat','CentOS'] {
        if $facts['os']['release']['major'] > '6' {
          ensure_resource('selboolean', 'nfsd_anon_write',
            {
              persistent => true,
              value      => 'on'
            }
          )
        }
      }
      else {
        fail("OS '${facts['os']['name']}' not supported by '${module_name}'")
      }
    }
    else {
      fail("OS Family '${facts['os']['family']}' not supported by ${module_name}")
    }
  }
}
