# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# Set up the iptables hooks and the sysctl settings that are required for NFS
# to function properly on a client system.
#
# If using the ``nfs::client::stunnel::connect`` define, this will be
# automatically called for you.
#
# @param callback_port
#   The callback port
#
# @param stunnel
#   Enable ``stunnel`` connections for this system
#
#   * Will *attempt* to determine if the server is trying to connect to itself
#
#   * If connecting to itself, will not use stunnel, otherwise will use stunnel
#
#   * If you are using host aliases for your NFS server names, this check
#     may fail and you may need to disable ``$stunnel`` explicitly
#
# @param stunnel_verify
#   The level at which to verify TLS connections
#
#   * See ``stunnel::connection::verify`` for details
#
# @param firewall
#   Use the SIMP IPTables module to manipulate the firewall settings
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
# @author Kendall Moore <kendall.moore@onyxpoint.com>
#
class nfs::client (
  Simplib::Port $callback_port  = 876,
  Boolean       $stunnel        = $::nfs::stunnel,
  Integer[0]    $stunnel_verify = 2,
  Boolean       $firewall       = $::nfs::firewall
) inherits ::nfs {

  assert_private()

  if !$nfs::is_server {
    file { '/etc/exports':
      ensure  => 'file',
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "\n"
    }
  }

  if $stunnel {
    include 'nfs::client::stunnel'
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
