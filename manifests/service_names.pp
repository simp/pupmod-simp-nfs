# == Class: nfs::service_names
#
# This class provides appropriate service names based on the operating system.
#
class nfs::service_names {
  if $::operatingsystem in ['RedHat', 'CentOS'] {
    $rpcbind   = 'rpcbind'

    if versioncmp($::operatingsystemmajrelease,'7') < 0 {
      $nfs_lock    = 'nfslock'
      $nfs_server  = 'nfs'
      $rpcgssd     = 'rpcgssd'
      $rpcidmapd   = 'rpcidmapd'
    }
    else {
      $nfs_lock    = 'nfs-lock'
      $nfs_mountd  = 'nfs-mountd'
      $nfs_rquotad = 'nfs-rquotad'
      $nfs_server  = 'nfs-server'
      $rpcgssd     = 'nfs-secure'
      $rpcidmapd   = 'nfs-idmap'
    }
  }
}
