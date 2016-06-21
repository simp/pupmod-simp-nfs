# Install the required NFS packages
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class nfs::install {
  package { 'nfs-utils':
    ensure  => 'latest'
  }

  package { 'nfs4-acl-tools':
    ensure => 'latest'
  }
}
