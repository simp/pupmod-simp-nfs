# define nfs::server::export
#
# Define to set up the /etc/exports file.
#
# @see exports(5)
#
# Be careful! The name of these mounts must be unique, but the only unique
# combination is mountpoint + client.  Therefore, you can actually have
# duplicate entries.
#
# NFS will function fine with this but the last duplicate entry in the file
# will win!
#
# Note: If `$client` is an array, then multiple identical entries will be created
# for each entry in the array.
#
# @param export_path The path on the filesystem to export.
#
# @param client An array of NFS exports-compatible clients to which
#   the export should be served. The entry will be repeated for each client.
#
# @param comment A comment to be added to the entry.
#
# @param insecure If set, do not require that requests originate on
#   an Internet port less than 1024.
#
# @param rw If set, allow both reads and writes on this volume.
#
# @param async If set, allow the NFS server to reply to request
#   before changes have been committed to stable storage.
#
# @param no_wdelay If set, disable write delays. Has no effect if
#   `$async` is set.
#
# @param nohide If set, disable hiding of subordinate filesystems.
#
# @param crossmnt If set, allow clients to access all filesystems
#   mounted on a filesystem marked with crossmnt.
#
# @param subtree_check If set, enable subtree checking.
#
# @param insecure_locks If set, do not require authentication of
#   locking requests.
#
# @param mountpoint Require the passed path to be
#   successfully mounted. If a boolean, then require the export path to be
#   successfully mounted.
#
# @param fsid A specific ID for the exported filesystem.
#
# @param nordirplus If set, disable READDIRPLUS request handling on
#   NFSv3 clients.
#
# @param refer A list of alternative locations for the filesystem.
#
# @param sec An Array of security flavors, in order of preference.
#
# @param no_root_squash If set, disable root squashing. This should
#   only be done if you *really* know what you are doing!
#
# @param all_squash If set, map all uids and gids to the `anonymous`
#   user.
#
# @param anonuid Explicity set the UID of the `anonymous` user.
#
# @param anongid Explicity set the GID of the `anonymous` user.

# @param custom A custom set of options.  If set, all other options
#   will be ignored. `$mountpoint` and `$client` must still be set.  Do *not*
#   include the parenthesis if you are writing a custom options string.
#
# @author Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
#
define nfs::server::export (
  Stdlib::Absolutepath                            $export_path,
  Array[String]                                   $client,
  Optional[String]                                $comment        = undef,
  Boolean                                         $insecure       = false,
  Boolean                                         $rw             = false,
  Boolean                                         $async          = false,
  Boolean                                         $no_wdelay      = false,
  Boolean                                         $nohide         = false,
  Boolean                                         $crossmnt       = false,
  Boolean                                         $subtree_check  = false,
  Boolean                                         $insecure_locks = false,
  Optional[Variant[Boolean,Stdlib::Absolutepath]] $mountpoint     = undef,
  Optional[String]                                $fsid           = undef,
  Boolean                                         $nordirplus     = false,
  Optional[String]                                $refer          = undef,
  Tuple[Enum['sys','krb5','krb5i','krb5p'],1,2]   $sec            = ['sys'],
  Boolean                                         $no_root_squash = false,
  Boolean                                         $all_squash     = false,
  Stdlib::Compat::Integer                         $anonuid        = '65534',
  Stdlib::Compat::Integer                         $anongid        = '65534',
  Optional[String]                                $custom         = undef
) {
  include '::nfs::server'

  validate_absolute_path($export_path)

  $_name = inline_template('<%= @name.gsub("/","|") -%>')

  simpcat_fragment { "nfs+${_name}.export":
    content => template('nfs/export.erb')
  }

  # We have to do this if we have a 'sec=sys' situation on EL7+
  if 'sys' in $sec {
    if $::osfamily == 'RedHat' {
      if $::operatingsystem in ['RedHat','CentOS'] {
        if $::operatingsystemmajrelease > '6' {
          ensure_resource('selboolean', 'nfsd_anon_write',
            {
              persistent => true,
              value      => 'on'
            }
          )
        }
      }
      else {
        fail("OS '${::operatingsystem}' not supported by '${module_name}'")
      }
    }
    else {
      fail("OS Family '${::osfamily}' is not supported by ${module_name}")
    }
  }
}
