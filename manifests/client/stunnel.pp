# == Class: nfs::client::stunnel
#
# Connect to an NFS server over stunnel
#
# You may need to change 'nfs_accept_port' to something different if you're
# targeting different servers using multiple tunnels.
#
# This is limited in that the migration features of NFS4 may not function since
# the callback port is not exposed via a reverse tunnel. This will be rectified
# when Kerberos is added to the systems.
#
# [*version*]
#   The version of NFS to use.  This has been tested for NFS versions 3 and 4
#
# [*nfs_accept_port*]
# [*nfs_connect_port*]
# [*portmapper_accept_port*]
# [*portmapper_connect_port*]
# [*rquotad_connect_port*]
# [*lockd_connect_port*]
# [*mountd_connect_port*]
# [*statd_connect_port*]
#
# == Authors
#
# * Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
# * Kendall Moore <mailto:kmoore@keywcorp.com>
#
class nfs::client::stunnel(
  $version = '4',
  $nfs_accept_port = '2049',
  $nfs_connect_port = '20490',
  $portmapper_accept_port = '111',
  $portmapper_connect_port = '1110',
  $rquotad_connect_port = '8750',
  $lockd_connect_port = '32804',
  $mountd_connect_port = '8920',
  $statd_connect_port = '6620',
) {
  include 'nfs::client'

  validate_integer($version)
  validate_port($nfs_accept_port)
  validate_port($nfs_connect_port)
  validate_port($portmapper_accept_port)
  validate_port($portmapper_connect_port)
  validate_port($rquotad_connect_port)
  validate_port($lockd_connect_port)
  validate_port($mountd_connect_port)
  validate_port($statd_connect_port)

  # Don't do this if you're running on yourself because, well, it's bad!
  if ! (host_is_me($nfs::nfs_server) or $nfs::is_server){
    include 'stunnel'

    if $version == '4' {
      stunnel::add { 'nfs_client':
        connect => ["${nfs::client::nfs_server}:${nfs_connect_port}"],
        accept  => "127.0.0.1:${nfs_accept_port}"
      }
    }
    else {
      stunnel::add { 'nfs_client':
        connect => ["${nfs::client::nfs_server}:${nfs_connect_port}"],
        accept  => "127.0.0.1:${nfs_accept_port}"
      }
      stunnel::add { 'portmapper':
        connect => ["${nfs::client::nfs_server}:${portmapper_connect_port}"],
        accept  => "127.0.0.1:${portmapper_accept_port}",
        require => Service[$::nfs::service_names::rpcbind]
      }
      stunnel::add { 'rquotad':
        connect => ["${nfs::client::nfs_server}:${rquotad_connect_port}"],
        accept  => "127.0.0.1:${nfs::rquotad_port}"
      }
      stunnel::add { 'lockd':
        connect => ["${nfs::client::nfs_server}:${lockd_connect_port}"],
        accept  => "127.0.0.1:${nfs::lockd_tcpport}"
      }
      stunnel::add { 'mountd':
        connect => ["${nfs::client::nfs_server}:${mountd_connect_port}"],
        accept  => "127.0.0.1:${nfs::mountd_port}"
      }
      stunnel::add { 'status':
        connect => ["${nfs::client::nfs_server}:${statd_connect_port}"],
        accept  => "127.0.0.1:${nfs::statd_port}"
      }
    }
  }
}
