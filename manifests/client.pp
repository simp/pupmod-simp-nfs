# Set up the iptables hooks and the sysctl settings that are required for NFS
# to function properly on a client system.
#
# If using the nfs::client::stunnel::connect define, this will be automatically
# called for you.
#
# @param nfs_server Array of NFS servers that will be
#   calling back to the callback port for NFSv4.
#
# @param is_server If set, lets this class know *explicitly* that
#   the `$nfs_server` is the host that the class is applying on. This is
#   important to avoid conflicts with the target server running on the same
#   host under a different hostname/alias.
#
#   @note The `File[/etc/exports]` resource will conflict if you have a system
#     that is both a server and client for itself but can't determine that from
#     introspection.
#
# @param callback_port The callback port.
#
# @param stunnel If set, will *attempt* to determine if the
#   server is trying to connect to itself. If connecting to itself, will not
#   use stunnel, otherwise will use stunnel.
#
#   @note If you are using host aliases for your NFS server names, this check
#     may fail and you may need to disable `$stunnel` explicitly.
#
# @param firewall If set, use the SIMP IPTables module to
#   manipulate the firewall settings.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
# @author Kendall Moore <kendall.moore@onyxpoint.com>
#
class nfs::client (
  String                   $nfs_server    = defined('$::nfs::server') ? { true => getvar('::nfs_server') , default => hiera('nfs::server') },
  Boolean                  $is_server     = $::nfs::is_server,
  Stdlib::Compat::Integer  $callback_port = '876',
  Boolean                  $stunnel       = $::nfs::stunnel,
  Boolean                  $firewall      = $::nfs::firewall,
) inherits ::nfs {

  validate_net_list($nfs_server)
  validate_port($callback_port)

  $_is_server = ($is_server or (host_is_me($nfs_server) and $stunnel))

  if !$_is_server {
    if $stunnel { include '::nfs::client::stunnel' }

    # If this explodes, your system has been unable to determine whether or not
    # it is the NFS server is question and you'll need to rectify that
    # directly using the `$is_server` variable in this class.

    file { '/etc/exports':
      ensure  => 'file',
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "\n"
    }
  }

  if $firewall {
    include '::iptables'

    iptables::add_tcp_stateful_listen { 'nfs4_callback_port':
      trusted_nets => $nfs_server,
      dports       => $callback_port
    }
  }

  exec { 'modprobe_nfs':
    command => '/sbin/modprobe nfs',
    unless  => '/sbin/lsmod | /bin/grep -qw nfs',
    require => [
      Package['nfs-utils'],
      File['/etc/modprobe.d/nfs.conf']
    ],
    notify  => Sysctl['fs.nfs.nfs_callback_tcpport']
  }

  sysctl { 'fs.nfs.nfs_callback_tcpport':
    ensure => 'present',
    val    => $callback_port,
    silent => true
  }

  file { '/etc/modprobe.d/nfs.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => "options nfs callback_tcpport=${callback_port}\n"
  }
}
