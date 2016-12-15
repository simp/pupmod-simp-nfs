# define nfs::server::stunnel
#
# Configures a server for NFS over stunnel.  Known to work with NFSv3 and
# NFSv4.
#
# @param version The version of NFS to use.  This has been tested with
#   NFSv3 and NFSv4. 'version' should be set to the numerical version
#   of NFS to use.
#
# @param trusted_nets The systems that are allowed to connect to this
#   service, as an array. Set to 'any' or 'ALL' to allow the world.
#
# @param nfs_accept_address The address upon which the NFS server will
#   listen. You should be able to set this to 0.0.0.0 for all interfaces.
#
# @param nfs_accept_port
#
# Note: All *_accept_port variables other than $nfs_accept_port do not apply
#
# @param portmapper_accept_port
#
# @param rquotad_accept_port
#
# @param nlockmgr_accept_port
#
# @param mountd_accept_port
#
# @param status_accept_port
#
# @author Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
# @author Kendall Moore <mailto:kmoore@keywcorp.com>
#
class nfs::server::stunnel (
  Stdlib::Compat::Integer  $version                = '4',
  Array[String]            $trusted_nets           = $::nfs::server::trusted_nets,
  String                   $nfs_accept_address     = '0.0.0.0',
  Stdlib::Compat::Integer  $nfs_accept_port        = '20490',
  Stdlib::Compat::Integer  $portmapper_accept_port = '1110',
  Stdlib::Compat::Integer  $rquotad_accept_port    = '8750',
  Stdlib::Compat::Integer  $nlockmgr_accept_port   = '32804',
  Stdlib::Compat::Integer  $mountd_accept_port     = '8920',
  Stdlib::Compat::Integer  $status_accept_port     = '6620'
) {
  include '::nfs::server'
  include '::stunnel'

  validate_net_list($trusted_nets)
  validate_net_list($nfs_accept_address)
  validate_port($nfs_accept_port)
  validate_port($portmapper_accept_port)
  validate_port($rquotad_accept_port)
  validate_port($nlockmgr_accept_port)
  validate_port($mountd_accept_port)
  validate_port($status_accept_port)

  Service[$::nfs::service_names::nfs_server] -> Service['stunnel']

  if $version == '4' {
    stunnel::add { 'nfs':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => ['2049'],
      accept       => "${nfs_accept_address}:${nfs_accept_port}"
    }

    $stunnel_port_override = [ $nfs_accept_port ]
  }
  else {
    stunnel::add { 'nfs':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => ['2049'],
      accept       => "${nfs_accept_address}:${nfs_accept_port}"
    }
    stunnel::add { 'portmapper':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => ['111'],
      accept       => "${nfs_accept_address}:${portmapper_accept_port}"
    }
    stunnel::add { 'rquotad':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => [$::nfs::rquotad_port],
      accept       => "${nfs_accept_address}:${rquotad_accept_port}"
    }
    stunnel::add { 'nlockmgr':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => [$::nfs::lockd_tcpport],
      accept       => "${nfs_accept_address}:${nlockmgr_accept_port}"
    }
    stunnel::add { 'mountd':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => [$::nfs::mountd_port],
      accept       => "${nfs_accept_address}:${mountd_accept_port}"
    }
    stunnel::add { 'status':
      client       => false,
      trusted_nets => $trusted_nets,
      connect      => [$::nfs::statd_port],
      accept       => "${nfs_accept_address}:${status_accept_port}"
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
}
