# This class provides appropriate service names based on the operating system
#
class nfs::service_names {
  simplib::assert_metadata($module_name)

  if ($facts['os']['name'] in ['RedHat', 'CentOS', 'OracleLinux']) {

    if (versioncmp($facts['os']['release']['major'], '7') < 0) {
      $nfs_lock    = 'nfslock'
      $nfs_server  = 'nfs'
      $rpcbind     = 'rpcbind'
      $rpcgssd     = 'rpcgssd'
      $rpcidmapd   = 'rpcidmapd'
      $rpcsvcgssd  = 'rpcsvcgssd'
    }
    else {
      # Services here should use the fully qualified service name
      # When Puppet runs `systemctl is-enabled <service>` without `.service`,
      # it doesn't know what to check the enabled status of, and returns
      # unknown
      $nfs_lock    = 'rpc-statd.service'
      $nfs_mountd  = 'nfs-mountd.service'
      $nfs_rquotad = 'nfs-rquotad.service'
      $nfs_server  = 'nfs-server.service'
      $rpcidmapd   = 'nfs-idmapd.service'
      $rpcgssd     = 'rpc-gssd.service'

      if (versioncmp($facts['os']['release']['full'], '7.1') < 0) {
        $rpcsvcgssd  = 'rpc-svcgssd.service'
      }
      else {
        $rpcsvcgssd  = 'gssproxy.service'
      }
      if (versioncmp($facts['os']['release']['full'], '7.4') < 0) {
        $rpcbind     = 'rpcbind.socket'
      }
      else {
        $rpcbind     = 'rpcbind.service'
      }
    }
  }
}
