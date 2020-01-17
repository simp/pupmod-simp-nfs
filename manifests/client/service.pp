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
    restart    => '/usr/bin/systemctl restart nfs-utils.service nfs-client.target'
  }

  if $nfs::client::blkmap {
    service { 'nfs-blkmap.service':
      ensure     => 'running',
      enable     => true,
      hasrestart => true
    }
  }
}
