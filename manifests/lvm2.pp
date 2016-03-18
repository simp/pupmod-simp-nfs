# == Class: nfs::lvm2
# This class is used to counterract a bug in nfs-utils;
# unless lvm2 is ensured latest, nfs-utils cannot upgrade.
# It will be removed once the bug is fixed upstream.
#
class nfs::lvm2(
  $ensure = 'latest'
) {
  package { 'lvm2':
    ensure => $ensure
  }
}
