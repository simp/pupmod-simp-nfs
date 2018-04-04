# Install the required NFS packages
#
# @param ensure
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class nfs::install (
  Enum['latest','present','absent'] $ensure = 'latest'
){
  package { 'nfs-utils':      ensure => $ensure }
  package { 'nfs4-acl-tools': ensure => $ensure }
}
