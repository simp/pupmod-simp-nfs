# @summary Manage NFS client-specific services
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::client::service
{

  assert_private()

  service { 'nfs-client.target':
    ensure     => 'running',
    enable     => true,
    # To ensure we pick up config changes and have dependent unit ordering
    # correct, restart nfs-utils and nfs-client at the same time. Serially
    # restarting these does not reliably work.
    hasrestart => false,
    restart    => '/usr/bin/systemctl restart nfs-utils.service nfs-client.target',
    before     => [
      Sysctl['sunrpc.tcp_slot_table_entries'],
      Sysctl['sunrpc.udp_slot_table_entries'],
      Sysctl['fs.nfs.nfs_callback_tcpport']
    ]
  }

  # Dynamically tune with the proper number of sunrpc slot entries.
  # Although these parameters will be loaded on boot because of entries in
  # /etc/modprobe.d/sunrpc.conf created by nfs::base::config, this will ensure
  # the settings are picked up sooner if the sunrpc kernel module was already
  # loaded when this manifest is applied.
  ensure_resource('sysctl', 'sunrpc.tcp_slot_table_entries', {
    ensure  => 'present',
    val     => $nfs::sunrpc_tcp_slot_table_entries,
    # Ignore failure if var-lib-nfs-rpc_pipefs.mount was not up
    # when the sysctl values were cached by the sysctl resource.
    silent  => true,
    comment => 'Managed by simp-nfs Puppet module'
  } )

  ensure_resource('sysctl', 'sunrpc.udp_slot_table_entries', {
    ensure  => 'present',
    val     => $nfs::sunrpc_udp_slot_table_entries,
    # Ignore failure if var-lib-nfs-rpc_pipefs.mount was not up
    # when the sysctl values were cached by the sysctl resource.
    silent  => true,
    comment => 'Managed by simp-nfs Puppet module'
  } )

  # Dynamically tune the client callback port.
  # Although this parameter will be loaded on boot because of an entry in
  # /etc/modprobe.d/nfs.conf created by nfs::client::config, this will ensure
  # the setting is picked up sooner if the nfsv4 kernel module was already
  # loaded when this manifest is applied.
  sysctl { 'fs.nfs.nfs_callback_tcpport':
    ensure  => 'present',
    val     => $nfs::client::callback_port,
    # Ignore failure if nfsv4 module was not loaded when the sysctl
    # values were cached by the sysctl resource.
    silent  => true,
    comment => 'Managed by simp-nfs Puppet module'
  }

  if $nfs::client::blkmap {
    service { 'nfs-blkmap.service':
      ensure     => 'running',
      enable     => true,
      hasrestart => true
    }
  }
}
