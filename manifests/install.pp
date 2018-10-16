# Install the required NFS packages
#
# @param ensure The ensure status of the nfs-utils package
#
# @param tools_ensure The ensure status of the nfs4-acl-tools package
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class nfs::install (
  String $ensure       = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  String $tools_ensure = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
) {
  package { 'nfs-utils':
    ensure => $ensure
  }
  package { 'nfs4-acl-tools':
    ensure => $tools_ensure
  }
}
