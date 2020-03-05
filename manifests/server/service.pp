# @summary Manage NFS server-specific services
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::server::service
{
  assert_private()

  service { 'nfs-server.service':
    ensure     => 'running',
    enable     => true,
    # To ensure we pick up config changes and have dependent unit ordering
    # correct, restart nfs-utils and nfs-server at the same time. Serially
    # restarting these does not reliably work.
    hasrestart => false,
    restart    => '/usr/bin/systemctl restart nfs-utils.service nfs-server.service',
    before     => [
      Sysctl['sunrpc.tcp_slot_table_entries'],
      Sysctl['sunrpc.udp_slot_table_entries']
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

  # nfs-mountd is required for both NFSv3 and NFSv4, is started when needed,
  # and only has over-the-wire operation in NFSv3
  svckill::ignore { 'nfs-mountd': }

  # Required by rpc-rquotad.service, but also may be part of base
  # services for NFSv3 or some other application.
  ensure_resource(
    'service',
    'rpcbind.service',
    {
      ensure     => 'running',
      enable     => true,
      hasrestart => true
    }
  )

  service { 'rpc-rquotad.service':
    ensure     => 'running',
    enable     => true,
    hasrestart => true
  }
}
