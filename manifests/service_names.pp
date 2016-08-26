# == Class: nfs::service_names
#
# This class provides appropriate service names based on the operating system.
#
class nfs::service_names {
  if $::operatingsystem in ['RedHat', 'CentOS'] {
    $rpcbind   = 'rpcbind'

    if (versioncmp($::operatingsystemmajrelease,'7') < 0) {
      $nfs_lock    = 'nfslock'
      $nfs_server  = 'nfs'
      $rpcgssd     = 'rpcgssd'
      $rpcidmapd   = 'rpcidmapd'
      $rpcsvcgssd  = 'rpcsvcgssd'
    }
    else {
      $nfs_lock    = 'rpc-statd'
      $nfs_mountd  = 'nfs-mountd'
      $nfs_rquotad = 'nfs-rquotad'
      $nfs_server  = 'nfs-server'
      $rpcidmapd   = 'nfs-idmapd'
      $rpcgssd     = 'rpc-gssd'

      if (versioncmp($::operatingsystemrelease,'7.1') < 0) {
        $rpcsvcgssd  = 'rpc-svcgssd'
      }
      else {
        $rpcsvcgssd  = ''
      }
    }
  }
  else {
    fail("Operating System '${::operatingsystem}' is not supported by ${module_name}")
  }
}
