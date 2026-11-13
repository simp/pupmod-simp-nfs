# @summary Manage configuration common to an NFS server and an NFS client
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::base::config {
  assert_private()

  # Required /etc/nfs.conf options for all possible NFS base services shared
  # by NFS client and NFS server
  # * Only config appropriate for specified NFS versions will actually be set.
  # * All values can be set via nfs class parameters
  # * Will override any $nfs::custom_nfs_conf_opts settings, because the
  #   firewall will not work otherwise!
  $_required_nfs_conf_opts = {
    'gssd'     => {
      'avoid-dns'                => $nfs::gssd_avoid_dns,
      'limit-to-legacy-enctypes' => $nfs::gssd_limit_to_legacy_enctypes,
      'use-gss-proxy'            => $nfs::gssd_use_gss_proxy
    },
    'lockd'     => {
      'port'                     => $nfs::lockd_port,
      'udp-port'                 => $nfs::lockd_udp_port,
    },
    'sm-notify' => {
      'outgoing-port'            => $nfs::sm_notify_outgoing_port
    },
    'statd'     => {
      'port'                     => $nfs::statd_port,
      'outgoing-port'            => $nfs::statd_outgoing_port
    }
  }

  $_merged_opts = deep_merge($nfs::custom_nfs_conf_opts,
  $_required_nfs_conf_opts)

  # Use concat so users can add new sections on their own, in the event NFS
  # configuration changes and this module has not yet been updated.
  concat { '/etc/nfs.conf':
    owner          => 'root',
    group          => 'root',
    mode           => '0644',
    ensure_newline => true,
    warn           => true,
    # Fragments in this module are ordered so that in a file containing all
    # sections (e.g., one with base and server config), the general section
    # comes first and all other sections are in alphabetical order.
    order          => 'numeric'
  }

  if 'general' in $_merged_opts {
    concat::fragment { 'nfs_conf_general':
      order   => 1,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
      { section => 'general', opts => $_merged_opts['general'] })
    }
  }

  if $nfs::secure_nfs {
    concat::fragment { 'nfs_conf_gssd':
      order   => 3,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
      { section => 'gssd', opts => $_merged_opts['gssd'] })
    }
  }

  if $nfs::nfsv3 {
    concat::fragment { 'nfs_conf_lockd':
      order   => 4,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
      { section => 'lockd', opts => $_merged_opts['lockd'] })
    }

    concat::fragment { 'nfs_conf_sm_notify':
      order   => 8,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
      { section => 'sm-notify', opts => $_merged_opts['sm-notify'] })
    }

    if 'statd' in $_merged_opts {
      concat::fragment { 'nfs_conf_statd':
        order   => 9,
        target  => '/etc/nfs.conf',
        content => epp("${module_name}/etc/nfs_conf_section.epp",
        { section => 'statd', opts => $_merged_opts['statd'] })
      }
    }
  }

  # The EL8 nfs-utils package provides and enables nfs-convert.service, which
  # runs when NFS services are started. If /etc/sysconfig/nfs exists, it
  # generates /etc/nfs.conf from it and then moves /etc/sysconfig/nfs to a
  # backup file. We don't want this generated /etc/nfs.conf! Nothing reads
  # /etc/sysconfig/nfs on EL9+.
  file { '/etc/sysconfig/nfs':
    ensure => 'absent',
    before => Concat['/etc/nfs.conf']
  }

  # Make sure gssproxy gets restarted in the correct order along with
  # all the other NFS services
  if $nfs::secure_nfs and $nfs::gssd_use_gss_proxy {
    $_override = @(OVERRIDE)
      # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
      # at the next puppet run.

      [Unit]

      PartOf=nfs-utils.service
      | OVERRIDE

    systemd::dropin_file { 'simp_unit.conf':
      unit    => 'gssproxy.service',
      content => $_override
    }
  }

  $_modprobe_d_sunrpc_conf = @("SUNRPC")
    # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
    # at the next puppet run.
    #
    options sunrpc tcp_slot_table_entries=${nfs::sunrpc_tcp_slot_table_entries} udp_slot_table_entries=${nfs::sunrpc_udp_slot_table_entries}
    | SUNRPC

  file { '/etc/modprobe.d/sunrpc.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => $_modprobe_d_sunrpc_conf
  }

  if $nfs::idmapd {
    include 'nfs::idmapd::config'
  }

  if $nfs::nfsv3 {
    # Have some difficulty ensuring custom lockd RPC ports from /etc/nfs.conf
    # are picked up immediately in two scenarios:
    # - NFS client reboot. The ports are not initially correctly registered
    #   with rpcbind (portmapper) at NFS client reboot.  They will show the
    #   wrong value for nlockmgr in 'rpcinfo -p' output, UNTIL the lock protocol
    #   is engaged (e.g., when the user flocks a file on the NFS share). At that
    #   time the correct ports will be used and reflected in 'rpcinfo -p'.
    #   This is a perception problem, not a real problem.
    # - NFS server is started without nfs-utils being simultaneously started.
    #   This is a real problem that can be fixed with
    #     'systemctl restart nfs-utils nfs-server',
    #   but not necessarily with
    #     'systemctl start nfs-server'.
    #   Depending upon the state of the system, a Puppet run may call
    #   the latter instead of the former and not fix the problem.
    #
    # To minimize these issues, set the lockd ports in a kernel module config
    # file. This will ensure the correct parameters are picked up when the
    # nfs kernel modules are loaded.
    #
    $_modprobe_d_lockd_conf = @("LOCKDCONF")
      # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
      # at the next puppet run.
      #
      # Set the TCP port that the NFS lock manager should use.
      # port must be a valid TCP port value (1-65535).
      options lockd nlm_tcpport=${nfs::lockd_port}

      # Set the UDP port that the NFS lock manager should use.
      # port must be a valid UDP port value (1-65535).
      options lockd nlm_udpport=${nfs::lockd_udp_port}
      | LOCKDCONF

    file { '/etc/modprobe.d/lockd.conf':
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => $_modprobe_d_lockd_conf,
    }
  }
}
