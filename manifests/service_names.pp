# This class provides appropriate service names based on the operating system
#
class nfs::service_names {
  if $facts['os']['name'] in ['RedHat', 'CentOS'] {

    if $facts['os']['release']['major'] == '6' {
      $nfs_lock    = 'nfslock'
      $nfs_server  = 'nfs'
      $rpcgssd     = 'rpcgssd'
      $rpcidmapd   = 'rpcidmapd'
      $rpcsvcgssd  = 'rpcsvcgssd'
      $rpcbind     = 'rpcbind'
    }
    else {
      $nfs_lock    = 'rpc-statd'
      $nfs_mountd  = 'nfs-mountd'
      $nfs_rquotad = 'nfs-rquotad'
      $nfs_server  = 'nfs-server'
      $rpcidmapd   = 'nfs-idmapd'
      $rpcgssd     = 'rpc-gssd'
      $rpcbind     = 'rpcbind.socket'

      if (versioncmp($facts['os']['release']['full'], '7.1') < 0) {
        $rpcsvcgssd  = 'rpc-svcgssd'
      }
      else {
        $rpcsvcgssd  = ''
      }
    }
  }
  else {
    fail("Operating System '${facts['os']['name']}' is not supported by ${module_name}")
  }
}
