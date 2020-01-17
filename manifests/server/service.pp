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
    restart    => '/usr/bin/systemctl restart nfs-utils.service nfs-server.service'
  }

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
