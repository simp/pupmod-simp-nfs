# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# Configure a NFS server with a default configuration that nails up the ports
# so that you can pass them through ``iptables``.
#
# This defaults to ``NFSv4``.
#
# @param trusted_nets
#   The systems that are allowed to connect to this service
#
#   * Set to ``any`` or ``ALL`` to allow the world
#
# @param nfsv3
#   Serve out ``NFSv3`` shares
#
# @param rpcrquotadopts
#   Options that should be passed to ``rquotad`` at start time
#
# @param lockd_arg
#   Options that should be passed to ``lockd`` at start time
#
# @param nfsd_module
#   If set to ``noload`` will prevent the ``nfsd`` kernel module from being
#   pre-loaded
#
#   * **NOTE:** if this is set to _anything_, the template will say ``noload``
#
# @param rpcmountdopts
#   An arbitrary string of options to pass to ``mountd`` at start time
#
# @param statdarg
#   An arbitrary string of options to pass to ``statd`` at start time
#
# @param statd_ha_callout
#   The path to an application that should be used for ``statd`` HA
#
# @param rpcidmapdargs
#   Artibrary arguments to pass to ``idmapd`` at start time
#
# @param rpcgssdargs
#   Arbitrary arguments to pass to ``gssd`` at start time
#
# @param rpcsvcgssdargs
#   Arbitrary arguments to pass to ``svcgssd`` at start time
#
# @param sunrpc_udp_slot_table_entries
#
#   Set the default UDP slot table entries in the kernel
#
#   * Most NFS server performance guides seem to recommend this setting
#
#   * If you have a low memory system, you may want to reduce this
#
# @param sunrpc_tcp_slot_table_entries
#
#   Set the default TCP slot table entries in the kernel
#
#   * Most NFS server performance guides seem to recommend this setting
#
#   * If you have a low memory system, you may want to reduce this
#
# @note Due to a bug in EL, ``$mountd_nfs_v1`` must be set to ``yes`` to
#   properly unmount
#
# @note The ``rpcbind`` port and the ``rpc.quotad`` ports are open to the
#   trusted networks so that the ``quota`` command works on the clients
#
# @param firewall
#   Use the SIMP ``iptables`` module to manage firewall connections
#
# @param stunnel Use the SIMP ``stunnel`` module to manage stunnel
#
# @param tcpwrappers
#   Use the SIMP ``tcpwrappers`` module to manage tcpwrappers
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
# @author Morgan Rhodes <morgan@puppet.com>
# @author Kendall Moore <kendall.moore@onyxpoint.com>
#
class nfs::server (
  Simplib::Netlist               $trusted_nets                  = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1'] }),
  Boolean                        $nfsv3                         = $::nfs::nfsv3,
  Optional[String]               $rpcrquotadopts                = undef,
  Optional[String]               $lockd_arg                     = undef,
  Optional[String]               $nfsd_module                   = undef,
  Optional[String]               $rpcmountdopts                 = undef,
  Optional[String]               $statdarg                      = undef,
  Optional[Stdlib::Absolutepath] $statd_ha_callout              = undef,
  Optional[String]               $rpcidmapdargs                 = undef,
  Optional[String]               $rpcgssdargs                   = undef,
  Optional[String]               $rpcsvcgssdargs                = undef,
  Integer[1]                     $sunrpc_udp_slot_table_entries = 128,
  Integer[1]                     $sunrpc_tcp_slot_table_entries = 128,
  Boolean                        $firewall                      = $::nfs::firewall,
  Boolean                        $stunnel                       = $::nfs::stunnel,
  Boolean                        $tcpwrappers                   = $::nfs::tcpwrappers
) inherits ::nfs {

  assert_private()

  if $tcpwrappers {
    include '::tcpwrappers'
  }

  if $stunnel {
    contain '::nfs::server::stunnel'

    # This is here due to some bug where allowing things through regularly
    # isn't working correctly.
    if $tcpwrappers {
      tcpwrappers::allow { 'nfs': pattern => 'ALL' }
    }
  }

  if $nfsv3 { include '::nfs::idmapd' }

  concat::fragment { 'nfs_init_server':
    target  => '/etc/sysconfig/nfs',
    content => template("${module_name}/etc/sysconfig/nfs_server.erb")
  }

  concat { '/etc/exports':
    owner          => 'root',
    group          => 'root',
    mode           => '0644',
    ensure_newline => true,
    warn           => true,
    notify         => Exec['nfs_re-export']
  }

  exec { 'nfs_re-export':
    command     => '/usr/sbin/exportfs -ra',
    refreshonly => true,
    require     => Package['nfs-utils']
  }

  service { $::nfs::service_names::nfs_server :
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
    hasstatus  => true
  }

  Service[$::nfs::service_names::rpcbind] -> Service[$::nfs::service_names::nfs_server]

  # Plopping this in place so that NFS starts with the proper number of slot
  # entries upon reboot.
  file { '/etc/init.d/sunrpc_tuning':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0754',
    content => template("${module_name}/server/sunrpc_tuning.erb")
  }

  # $stunnel_port_override is a value that is set by the stunnel overlay.
  if $stunnel and $::nfs::server::stunnel::stunnel_port_override {
    if $firewall {
      include '::iptables'

      iptables::listen::tcp_stateful{ 'nfs_client_tcp_ports':
        trusted_nets => $trusted_nets,
        dports       => $::nfs::server::stunnel::stunnel_port_override
      }
      iptables::listen::udp { 'nfs_client_udp_ports':
        trusted_nets => $trusted_nets,
        dports       => $::nfs::server::stunnel::stunnel_port_override
      }
    }
  }
  else {
    if ( $::nfs::mountd_nfs_v2 ) or ( $::nfs::mountd_nfs_v3 ) {
      $_ports = [
        111,
        2049,
        $::nfs::rquotad_port,
        $::nfs::lockd_tcpport,
        $::nfs::mountd_port,
        $::nfs::statd_port
      ] # <-- End ports
    }
    else {
      $_ports = [
        111,
        2049,
        $::nfs::rquotad_port
      ]
    }

    if $firewall {
      include '::iptables'

      iptables::listen::tcp_stateful { 'nfs_client_tcp_ports':
        trusted_nets => $trusted_nets,
        dports       => $_ports
      }
      iptables::listen::udp { 'nfs_client_udp_ports':
        trusted_nets => $trusted_nets,
        dports       => $_ports
      }
    }
  }

  service { 'sunrpc_tuning':
    enable  => true,
    require => [
      File['/etc/init.d/sunrpc_tuning'],
      Service[$::nfs::service_names::nfs_server]
    ]
  }

  if $tcpwrappers {
    tcpwrappers::allow { [
      'mountd',
      'statd',
      'rquotad',
      'lockd',
      'rpcbind'
      ]:
      pattern => $trusted_nets
    }
  }

  sysctl { 'sunrpc.tcp_slot_table_entries':
    ensure => 'present',
    val    => $sunrpc_tcp_slot_table_entries,
    silent => true,
    notify => Service[$::nfs::service_names::nfs_server]
  }

  sysctl { 'sunrpc.udp_slot_table_entries':
    ensure => 'present',
    val    => $sunrpc_udp_slot_table_entries,
    silent => true,
    notify => Service[$::nfs::service_names::nfs_server]
  }

  if $::nfs::secure_nfs {
    if !empty($::nfs::service_names::rpcsvcgssd) {
      service { $::nfs::service_names::rpcsvcgssd :
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true
      }

      Service[$::nfs::service_names::rpcbind] -> Service[$::nfs::service_names::rpcsvcgssd]
    }

    Service[$::nfs::service_names::rpcbind] -> Sysctl['sunrpc.tcp_slot_table_entries']
    Service[$::nfs::service_names::rpcbind] -> Sysctl['sunrpc.udp_slot_table_entries']
    Sysctl['sunrpc.tcp_slot_table_entries'] ~> Service[$::nfs::service_names::nfs_lock]
    Sysctl['sunrpc.udp_slot_table_entries'] ~> Service[$::nfs::service_names::nfs_lock]
  }
}
