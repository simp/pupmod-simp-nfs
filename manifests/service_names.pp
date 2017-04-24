# This class provides appropriate service names based on the operating system
#
class nfs::service_names {
  if ($facts['os']['name'] in ['RedHat', 'CentOS']) {

    if (versioncmp($facts['os']['release']['major'], '7') < 0) {
      $nfs_lock    = 'nfslock'
      $nfs_server  = 'nfs'
      $rpcbind     = 'rpcbind'
      $rpcgssd     = 'rpcgssd'
      $rpcidmapd   = 'rpcidmapd'
      $rpcsvcgssd  = 'rpcsvcgssd'
    }
    else {
      $nfs_lock    = 'rpc-statd'
      $nfs_mountd  = 'nfs-mountd'
      $nfs_rquotad = 'nfs-rquotad'
      $nfs_server  = 'nfs-server'
      $rpcbind     = 'rpcbind.socket'
      $rpcidmapd   = 'nfs-idmapd'
      $rpcgssd     = 'rpc-gssd'

      if (versioncmp($facts['os']['release']['full'], '7.1') < 0) {
        $rpcsvcgssd  = 'rpc-svcgssd'
      }
      else {
        $rpcsvcgssd  = 'gssproxy'
      }
    }
  }
  else {
    fail("Operating System '${facts['os']['name']}' is not supported by ${module_name}")
  }
}
