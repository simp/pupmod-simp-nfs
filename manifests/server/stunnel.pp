# == Define: nfs::server::stunnel
#
# Configures a server for NFS over stunnel.  Known to work with NFSv3 and
# NFSv4.
#
# == Parameters
#
# [*version*]
#   The version of NFS to use.  This has been tested with NFSv3 and NFSv4.
#   'version' should be set to the numerical version of NFS to use.
#
# [*client_ips*]
#   The systems that are allowed to connect to this service, as an array. Set
#   to 'any' or 'ALL' to allow the world.
#
# [*rquotad_port*]
# [*lockd_tcpport*]
# [*mountd_port*]
# [*statd_port*]
# [*nfs_accept_address*]
#   The address upon which the NFS server will listen. You should be able to
#   set this to 0.0.0.0 for all interfaces.
#
# [*nfs_accept_port*]
#
# Note: All *_accept_port variables other than $nfs_accept_port do not apply
#
# [*portmapper_accept_port*]
# [*rquotad_accept_port*]
# [*nlockmgr_accept_port*]
# [*mountd_accept_port*]
# [*status_accept_port*]
#
# == Authors
#
# * Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
# * Kendall Moore <mailto:kmoore@keywcorp.com>
#
class nfs::server::stunnel (
  $version = '4',
  $client_ips = $::nfs::server::client_ips,
  $nfs_accept_address = '0.0.0.0',
  $nfs_accept_port = '20490',
  $portmapper_accept_port = '1110',
  $rquotad_accept_port = '8750',
  $nlockmgr_accept_port = '32804',
  $mountd_accept_port = '8920',
  $status_accept_port = '6620'
) {
  include '::nfs::server'

  Service['nfs'] -> Service['stunnel']

  if $version == '4' {
    stunnel::add { 'nfs':
      client      => false,
      client_nets => $client_ips,
      connect     => ['2049'],
      accept      => "${nfs_accept_address}:${nfs_accept_port}"
    }

    $stunnel_port_override = [ $nfs_accept_port ]
  }
  else {
    stunnel::add { 'nfs':
      client      => false,
      client_nets => $client_ips,
      connect     => ['2049'],
      accept      => "${nfs_accept_address}:${nfs_accept_port}"
    }
    stunnel::add { 'portmapper':
      client      => false,
      client_nets => $client_ips,
      connect     => ['111'],
      accept      => "${nfs_accept_address}:${portmapper_accept_port}"
    }
    stunnel::add { 'rquotad':
      client      => false,
      client_nets => $client_ips,
      connect     => [$nfs::rquotad_port],
      accept      => "${nfs_accept_address}:${rquotad_accept_port}"
    }
    stunnel::add { 'nlockmgr':
      client      => false,
      client_nets => $client_ips,
      connect     => [$nfs::lockd_tcpport],
      accept      => "${nfs_accept_address}:${nlockmgr_accept_port}"
    }
    stunnel::add { 'mountd':
      client      => false,
      client_nets => $client_ips,
      connect     => [$nfs::mountd_port],
      accept      => "${nfs_accept_address}:${mountd_accept_port}"
    }
    stunnel::add { 'status':
      client      => false,
      client_nets => $client_ips,
      connect     => [$nfs::statd_port],
      accept      => "${nfs_accept_address}:${status_accept_port}"
    }

    $stunnel_port_override = [
      $nfs_accept_port,
      $portmapper_accept_port,
      $rquotad_accept_port,
      $nlockmgr_accept_port,
      $mountd_accept_port,
      $status_accept_port
    ]
  }

  validate_port($nfs_accept_port)
  validate_port($portmapper_accept_port)
  validate_port($rquotad_accept_port)
  validate_port($nlockmgr_accept_port)
  validate_port($mountd_accept_port)
  validate_port($status_accept_port)
}
