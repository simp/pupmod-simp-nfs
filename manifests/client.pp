# == Class: nfs::client
#
# Set up the few IPTables rules that the client needs to provide NFSv4 callback
# capabilities from the server.
#
# If using the nfs::client::stunnel::connect define, this will be automatically
# called for you.
#
# If you call this define multiple times, make sure you use the same callback
# port each time, otherwise you will not get the results that you expect. If in
# doubt, just use the default.
#
# == Parameters
#
# [*nfs_server*]
#   The NFS server to connect to.
#
# [*callback_port*]
#   The callback port.
#
# [*use_stunnel*]
#   Type: Boolean
#   Default: ''
#     If set, will override any guessing that we can do and will
#     simply configure stunnel based on the set preference.
#
# == Authors
#
# * Trevor Vaughan <mailto:tvaughan@onyxpoint.com>
# * Kendall Moore <mailto:kmoore@keywcorp.com>
#
class nfs::client (
  $nfs_server = hiera('nfs::server'),
  $callback_port = '876',
  $use_stunnel = ''
) {
  include 'nfs'

  iptables::add_tcp_stateful_listen { "nfs4_callback_port_${nfs_server}":
    client_nets => $nfs_server,
    dports      => $callback_port
  }

  if ! defined(Sysctl::Value['fs.nfs.nfs_callback_tcpport']) {
    exec { 'modprobe_nfs':
      command => '/sbin/modprobe nfs',
      onlyif  => '/sbin/lsmod | /bin/grep -w nfs; /usr/bin/test $? -ne 0',
      require => Package['nfs-utils'],
      notify  => Sysctl::Value['fs.nfs.nfs_callback_tcpport']
    }

    sysctl::value { 'fs.nfs.nfs_callback_tcpport':
      value   => $callback_port
    }
  }

  file { '/etc/modprobe.d/nfs.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => "options nfs callback_tcpport=${callback_port}"
  }

  if (!empty($use_stunnel) and $use_stunnel) or (!host_is_me($nfs_server) and $nfs::use_stunnel) {
    include 'nfs::client::stunnel'
  }

  validate_port($callback_port)
  if !empty($use_stunnel) { validate_bool($use_stunnel) }
}
