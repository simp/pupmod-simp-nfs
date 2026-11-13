# @summary Manage NFS server-specific configuration
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::server::config {
  assert_private()

  # Required config options for all possible NFS server services.
  # * Augments the base config shared with NFS client.
  # * Only config appropriate for specified NFS versions will actually be set.
  # * Will override any $nfs::custom_nfs_conf_opts settings, because the
  #   firewall will not work otherwise!
  $_required_nfs_conf_opts = {
    'mountd' => {
      'port' => $nfs::server::mountd_port,
    },
    'nfsd'   => {
      'port'    => $nfs::server::nfsd_port,
      'vers2'   => false,
      'vers3'   => $nfs::server::nfsd_vers3,
      'vers4'   => $nfs::server::nfsd_vers4,
      'vers4.0' => $nfs::server::nfsd_vers4_0,
      'vers4.1' => $nfs::server::nfsd_vers4_1,
      'vers4.2' => $nfs::server::nfsd_vers4_2
    },
  }

  if $nfs::server::stunnel {
    # UDP can't be encapsulated by stunnel, so we have to force this
    # setting.manifests/base/service.pp
    $_stunnel_opts = { 'nfsd' => { 'tcp' => true, 'udp' => false } }
  } else {
    $_stunnel_opts = {}
  }

  $_merged_opts = deep_merge($nfs::custom_nfs_conf_opts,
  $_required_nfs_conf_opts, $_stunnel_opts)

  if 'exportfs' in $_merged_opts {
    concat::fragment { 'nfs_conf_exportfs':
      order   => 2,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
      { section => 'exportfs', opts => $_merged_opts['exportfs'] })
    }
  }

  if 'mountd' in $_merged_opts {
    concat::fragment { 'nfs_conf_mountd':
      order   => 5,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
      { section => 'mountd', opts => $_merged_opts['mountd'] })
    }
  }

  concat::fragment { 'nfs_conf_nfsd':
    order   => 6,
    target  => '/etc/nfs.conf',
    content => epp("${module_name}/etc/nfs_conf_section.epp",
    { section => 'nfsd', opts => $_merged_opts['nfsd'] })
  }

  if 'nfsdcltrack' in $_merged_opts {
    concat::fragment { 'nfs_conf_nfsdcltrack':
      order   => 7,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
      { section => 'nfsdcltrack', opts => $_merged_opts['nfsdcltrack'] })
    }
  }

  if $nfs::server::custom_rpcrquotad_opts {
    $_rpcrquotadopts = "${nfs::server::custom_rpcrquotad_opts} -p ${nfs::server::rquotad_port}"
  } else {
    $_rpcrquotadopts = "-p ${nfs::server::rquotad_port}"
  }

  $_sysconfig_rpc_rquotad = @("SYSCONFIGRPCRQUOTAD")
    # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
    # at the next puppet run.
    #
    RPCRQUOTADOPTS="${_rpcrquotadopts}"
    | SYSCONFIGRPCRQUOTAD

  file { '/etc/sysconfig/rpc-rquotad':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => $_sysconfig_rpc_rquotad
  }

  concat { '/etc/exports':
    owner          => 'root',
    group          => 'root',
    mode           => '0644',
    ensure_newline => true,
    warn           => true,
  }

  $_simp_etc_exports_path = @("HEREDOC")
    # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
    # at the next puppet run.

    [Path]
    Unit=simp_etc_exports.service
    PathChanged=/etc/exports

    [Install]
    WantedBy=multi-user.target
    | HEREDOC

  systemd::unit_file { 'simp_etc_exports.path':
    enable  => true,
    active  => true,
    content => $_simp_etc_exports_path
  }

  $_simp_etc_exports_service = @("HEREDOC")
    # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
    # at the next puppet run.

    [Service]
    Type=simple
    ExecStart=/usr/sbin/exportfs -ra
    | HEREDOC

  systemd::unit_file { 'simp_etc_exports.service':
    # 'static' service can't really be enabled, but this does no harm and
    # prevents svckill from killing it when it is running
    enable  => true,
    content => $_simp_etc_exports_service
  }
}
