# == Define: nfs::server::export
#
# Define to set up the /etc/exports file.
#
# Sane defaults are set based on the exports(5) man page.
#
# Be careful! The name of these mounts must be unique, but the only unique
# combination is mountpoint + client.  Therefore, you can actually have
# duplicate entries.
#
# NFS will function fine with this but the last duplicate entry in the file will
# win!
#
# Note: If $client is an array, then multiple identical entries will be created
# for each entry in the array.
#
#  == Parameters
#
# [*export_path*]
# [*client*]
# [*comment*]
#   A comment to add to the entry.
#
# [*insecure*]
# [*rw*]
# [*async*]
# [*no_wdelay*]
# [*nohide*]
# [*crossmnt*]
# [*subtree_check*]
# [*insecure_locks*]
# [*no_acl*]
# [*mountpoint*]
# [*fsid*]
# [*refer*]
# [*sec*]
# [*no_root_squash*]
# [*all_squash*]
# [*anonuid*]
# [*anongid*]
# [*custom*]
#   A custom set of options.  If $custom is set, all other options will be
#   ignored. $mountpoint and $client must still be set.  Do not include the
#   parenthesis if you are writing a custom options string.
#
# == Authors
#
# * Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
#
define nfs::server::export (
  $export_path,
  $client,
  $comment = '',
  $insecure = false,
  $rw = false,
  $async = false,
  $no_wdelay = false,
  $nohide = false,
  $crossmnt = false,
  $subtree_check = false,
  $insecure_locks = false,
  $no_acl = false,
  $mountpoint = '',
  $fsid = '',
  $refer = '',
  $sec = 'krb5p:krb5i:krb5',
  $no_root_squash = false,
  $all_squash = false,
  $anonuid = '65534',
  $anongid = '65534',
  $custom = ''
) {
  include 'nfs::server'

  validate_bool($insecure)
  validate_bool($rw)
  validate_bool($async)
  validate_bool($no_wdelay)
  validate_bool($nohide)
  validate_bool($crossmnt)
  validate_bool($subtree_check)
  validate_bool($insecure_locks)
  validate_bool($no_acl)
  validate_bool($no_root_squash)
  validate_bool($all_squash)

  $lname = inline_template('<%= @name.gsub("/","|") -%>')

  concat_fragment { "nfs+${lname}.export":
    content => template('nfs/export.erb')
  }
}
