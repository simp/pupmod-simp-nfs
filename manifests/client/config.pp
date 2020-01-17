# @summary Manage NFS client-specific configuration
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::client::config {

  assert_private()

  # We need to configure the NFSv4.0 client delegation callback port for the
  # nfsv4 kernel module, to ensure the port will pass through a firewall (i.e.,
  # is not ephemeral).  Normally, the nfsv4 kernel module would be loaded when
  # the mount requiring it is executed.  This dynamic loading doesn't play
  # well with sysctl.  So, we are going to ensure the kernel module is
  # configured properly with a static configuration file, load the module if
  # necessary, and, in case it was already loaded, set the value by sysctl.
  #
  # NOTE: The parameter has to be configured via the nfs kernel module (a
  # dependency of the nfsv4 kernel module), but won't be activated until the
  # nfsv4 module is loaded.
  #
  exec { 'modprobe_nfsv4':
    command => '/sbin/modprobe nfsv4',
    unless  => '/sbin/lsmod | /usr/bin/grep -qw nfsv4',
    require =>  File['/etc/modprobe.d/nfs.conf'],
    notify  => Sysctl['fs.nfs.nfs_callback_tcpport']
  }

  sysctl { 'fs.nfs.nfs_callback_tcpport':
    ensure  => 'present',
    val     => $nfs::client::callback_port,
    # Ignore 'invalid' kernel parameter, because the sysctl custom type caches
    # all kernel param info the first time any sysctl resource is created. So,
    # the parameter may appear to not be activated, even when it has just been
    # activated by the module we loaded in Exec['modprobe_nfsv4'].
    silent  => true,
    comment => 'Managed by simp-nfs Puppet module'
  }

  $_modprobe_d_nfs_conf = @("NFSCONF")
    # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
    # at the next puppet run.
    #
    options nfs callback_tcpport=${nfs::client::callback_port}
    | NFSCONF

  file { '/etc/modprobe.d/nfs.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => $_modprobe_d_nfs_conf
  }

  if !$nfs::is_server {
    file { '/etc/exports':
      ensure  => 'file',
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "\n"
    }
  }

  if $nfs::tcpwrappers {
    include 'nfs::client::tcpwrappers'
  }

  if $nfs::idmapd {
    include 'nfs::idmapd::client'
  }
}
