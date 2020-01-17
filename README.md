[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/nfs.svg)](https://forge.puppetlabs.com/simp/nfs)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/nfs.svg)](https://forge.puppetlabs.com/simp/nfs)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-nfs.svg)](https://travis-ci.org/simp/pupmod-simp-nfs)

#### Table of Contents

* [Description](#description)
  * [This is a SIMP module](#this-is-a-simp-module)
* [Setup](#setup)
    * [What nfs affects](#what-nfs-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with nfs](#beginning-with-nfs)
* [Usage](#usage)
    * [Basic Usage](#basic-usage)
    * [Usage with krb5](#usage-with-krb5)
    * [Usage with stunnel](#usage-with-stunnel)
    * [Other security features](#other-security-features)
* [Reference](#reference)
* [Limitations](#limitations)
* [Development - Guide for contributing to the module](#development)
    * [Acceptance Tests - Beaker env variables](#acceptance-tests)

## Description

The is a module for managing the exporting and mounting of NFS devices. It
provides all the infrastructure needed to share folders over the network.

The module is broken into two parts: the server and the client. It supports
security with either krb5 or stunnel, but not both, as these security services
conflict at a system level.  It also manages firewall and TCP wrapper settings,
when enabled.

### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.

If you find any issues, they may be submitted to our [bug tracker](https://simp-project.atlassian.net/).

This module is optimally designed for use within a larger SIMP ecosystem, but
it can be used independently:

 * When included within the SIMP ecosystem, security compliance settings will
   be managed from the Puppet server.
 * If used independently, all SIMP-managed security subsystems are disabled by
   default and must be explicitly opted into by administrators.  See the
   [SIMP `simp_options` module](https://github.com/simp/pupmod-simp-simp_options)
   for more detail.

## Setup

### What nfs affects

The `nfs` module installs NFS packages, configures services for the
NFS server and/or client and manages most NFS configuration files.

### Setup Requirements

The only requirement is to include the `nfs` module and its dependencies
in your modulepath.

*  If you are using any of the `nfs` module's optional dependencies, e.g.
  `autofs`, please also include those modules in the module path as well.
   The list of optional dependencies can be found in the `nfs` module's
   `metadata.json` file under `simp/optional_dependencies`.

### Beginning with nfs

You can use the `nfs` module to manage NFS settings for a node that is a NFS
client, a NFS server or both.

#### NFS client

Including one or more `nfs::client::mount` defines in a node's manifest
will automatically include the `nfs::client` class, which, in turn, will
ensure the appropriate packages are installed and appropriate services
are configured and started.

#### NFS server

Including one or more `nfs::server::export` defines in a node's manifest
and setting the hiera below will automatically include the `nfs::server`
class, which, in turn, will ensure the appropriate packages are installed and
appropriate services are configured.

``` yaml
nfs::is_server: true
nfs::is_client: false
```

#### NFS server and client

Including one or more `nfs::server::export` or `nfs::client::mount` defines
in a node's manifest and setting the hiera below will automatically include
the `nfs::server` and `nfs::client` classes. This will, in turn, ensure
the appropriate packages are installed and appropriate services are configured
for both roles.

``` yaml
nfs::is_server: true
```

## Usage

### Basic Usage

#### Exporting a filesystem

To export `/srv/nfs_share`, add the following to the NFS server's manifest:

``` puppet
  nfs::server::export { 'nfs4_root':
    client      => [ <trusted networks> ]
    export_path => '/srv/nfs_share',
    require     => File['/srv/nfs_share']
  }

  file { '/srv/nfs_share':
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0644'
  }
```

Be sure to set the following in hiera, as well:

``` yaml
nfs::is_server: true
```

#### Mounting

##### Static mount

To mount `/srv/nfs_share` statically to `/mnt/nfs` on the NFS client using
NFSv4, add the following to the NFS client's manifest:

``` puppet
$mount_dir = '/mnt/nfs'

nfs::client::mount { $mount_dir:
  nfs_server  => '<NFS server IP>',
  remote_path => '/srv/nfs_share',
  autofs      => false
}

# mount directory must exist if not using autofs
file { $mount_dir:
  ensure => 'directory',
  owner  => 'root',
  group  => 'root',
  mode   => '0644'
}

File[$mount_dir] -> Nfs::Client::Mount[$mount_dir]
```
##### Automatic direct mount

To automount `/exports/data` as `/data` using an direct mount,
add the following to the NFS client's manifest:

``` puppet
nfs::client::mount { '/data':
  nfs_server  => '<NFS server IP>',
  remote_path => '/exports/data'
}
```

##### Automatic indirect mount

To automount `/exports/apps` as `/apps` using an indirect mount with key
substitution, add the following to the NFS client's manifest:

``` puppet
nfs::client::mount { '/apps':
  nfs_server              => '<NFS server IP>',
  remote_path             => '/exports/apps',
  autofs_indirect_map_key => '*',
  autofs_add_key_subst    => true
}
```

##### Automatic mount of home directories for LDAP users

Please reference the [SIMP documentation](https://simp.readthedocs.io/en/stable/user_guide/HOWTO/NFS.html#exporting-home-directories) for details on how to implement this feature.

### Usage with krb5

--------------------

> **WARNING**
>
> This functionality requires some manual configuration and when keys
> change may require manual purging of the `gssproxy` cache.

--------------------

This module, used with the [SIMP `krb5` module](https://github.com/simp/pupmod-simp-krb5),
can automatically use kerberos to secure the exported filesystem. The module
can create and manage the entire kerberos configuration automatically, but
check the `krb5` module itself if you want more control.

Modify the examples provided above to include the following hieradata on
all nodes:

``` yaml
simp_options::kerberos: true
nfs::secure_nfs: true

krb5::config::dns_lookup_kdc: false
krb5::kdc::auto_keytabs::global_services:
  - 'nfs'
```

On the node intended to be the KDC, include the following class:

``` yaml
include 'krb5::kdc'
```

On the NFS server and client nodes, add the following to each node's manifest:

```puppet
# If your realm is not your domain name then change this
# to the string that is your realm
$myrealm = upcase($facts['domain'])

krb5::setting::realm { $myrealm:
  admin_server   => <KDC fqnd>,
  default_domain => $myrealm
}
```

SIMP does not have kerberos set up to work automatically with LDAP yet. You
must add a principal for each user you want to give access to the krb5 protected
directories. To do this log onto the KDC and run:

```bash
kadmin.local
# Note the prompt is now kadmin.local!
kadmin.local:  add_principal -pw <password> <username>
...
kadmin.local:  exit
```
When the user logs on after kerberos has been configured they must run:

```bash
kinit
```

It will ask them for their password. Once the have done this they should be
able to access any shares from that realm.

### Usage with stunnel

When use of kerberos is not viable, but you want to encrypt NFS traffic,
you can configure the NFS server and client to use `stunnel` automatically
on NFSv4 connections.

This module uses the [SIMP `stunnel` module](https://github.com/simp/pupmod-simp-stunnel)
for `stunnel` management.

#### NFSv4 stunnel, one NFS server

In this scenario, we will consider a site with one NFS server.

##### Export with stunnel

To enable use of stunnel at the NFS server, set the following in hieradata:

``` yaml
nfs::is_server: true
nfs::stunnel: true
```
To export `/srv/nfs_share`, add the following to the NFS server's manifest:

``` puppet
nfs::server::export { 'nfs4_root':
  client      => [ <trusted networks> ]
  export_path => '/srv/nfs_share',
  # This MUST be set to true due to a NFS exports processing bug.
  # See description in nfs::server::export.
  insecure    => true,
  require     => File['/srv/nfs_share']
}

file { '/srv/nfs_share':
  ensure => 'directory',
  owner  => 'root',
  group  => 'root',
  mode   => '0644'
}
```

##### Mount with stunnel

To enable use of stunnel at the NFS client, set the following in hieradata:

``` yaml
nfs::stunnel: true
```

To mount `/srv/nfs_share` statically to `/mnt/nfs` on the NFS client,
add the following to the NFS client's manifest:

``` puppet
$mount_dir = '/mnt/nfs'

nfs::client::mount { $mount_dir:
  nfs_server  => '<NFS server IP>',
  remote_path => '/srv/nfs_share',
  autofs      => false
}

# mount directory must exist if not using autofs
file { $mount_dir:
 ensure => 'directory',
 owner  => 'root',
 group  => 'root',
 mode   => '0644'
}

File[$mount_dir] -> Nfs::Client::Mount[$mount_dir]
```

In this simple case, the mount manifest looks exactly the same as
in the unencrypted case.  Only the hieradata has changed.

#### NFSv4 stunnel, multiple NFS servers

In this scenario, we will consider a site with two NFS servers. The example
shown can be extrapolated to any number of NFS servers.

##### Server 1 export with stunnel

The first NFS server will be configured exactly as is done with the
single server example above.

Server 1 hieradata:

``` yaml
nfs::is_server: true
nfs::stunnel: true
```

Server 1 manifest:

``` puppet
nfs::server::export { 'nfs4_root':
  client      => [ <trusted networks> ]
  export_path => '/srv/nfs_share',
  # This MUST be set to true due to a NFS exports processing bug
  insecure    => true,
  require     => File['/srv/nfs_share']
}

file { '/srv/nfs_share':
  ensure => 'directory',
  owner  => 'root',
  group  => 'root',
  mode   => '0644'
}
```

##### Server 2 export with stunnel

The second NFS server requires a little more configuration.

To enable use of stunnel at this NFS server and prevent port conflicts
with Server 1 on any client that wants to mount from both servers over
stunnel, set the following in hieradata:

``` yaml
nfs::is_server: true
nfs::stunnel: true

# The nfsd port must be unique among all NFS servers at the site.
# The stunnel nfsd port is configured here for consistency, but
# could be left at the default.
nfs::nfsd_port: 2050
nfs::stunnel_nfsd_port: 20500
```

To export `/srv/nfs_share2`, add the following to Server 2's manifest:

``` puppet
nfs::server::export { 'nfs4_root':
  client      => [ <trusted networks> ]
  export_path => '/srv/nfs_share2',
  # This MUST be set to true due to a NFS exports processing bug
  insecure    => true,
  require     => File['/srv/nfs_share2']
}

file { '/srv/nfs_share2':
  ensure => 'directory',
  owner  => 'root',
  group  => 'root',
  mode   => '0644'
}
```

##### Mounts to servers with stunnel

To enable use of stunnel at the NFS client, set the following in hieradata:

``` yaml
nfs::stunnel: true
```

To mount `/srv/nfs_share` from Server 1 statically to `/mnt/nfs`
and `/srv/nfs_share2` from Server 2 statically to `/mnt/nfs2`,
add the following to the NFS client's manifest:

``` puppet
# this mount uses the defaults, because Server 1 uses nfs
# module defaults
$mount_dir = '/mnt/nfs'
nfs::client::mount { $mount_dir:
  nfs_server  => '<NFS Server 1 IP>',
  remote_path => '/srv/nfs_share',
  autofs      => false
}

# this mount sets ports to match those of Server 2
$mount_dir2 = '/mnt/nfs2'
nfs::client::mount { $mount_dir2:
  nfs_server        => '<NFS Server 2 IP>',
  remote_path       => '/srv/nfs_share2',
  autofs            => false,
  nfsd_port         => 2050,
  stunnel_nfsd_port => 20500
}

# mount directories must exist if not using autofs
file { [ $mount_dir, $mount_dir2 ]:
 ensure => 'directory',
 owner  => 'root',
 group  => 'root',
 mode   => '0644'
}

File[$mount_dir] -> Nfs::Client::Mount[$mount_dir]
File[$mount_dir2] -> Nfs::Client::Mount[$mount_dir2]
```

#### NFSv3 considerations

NFSv3 traffic cannot be encrypted with `stunnel` because of two key reasons:

* The NFS client sends the NFS server Network Status Manager (NSM) notifications
  via UDP, exclusively.

  * `stunnel` only handles TCP traffic.
  * Loss of these notification may affect NFS performance.

* In multi-NFS-server environments, there is no mechanism to configure `rpcbind`
  to use a non-standard port.

  * NFSv3 heavily relies upon `rpcbind` to determine the side-band channel ports
    in use on the NFS nodes.  This includes the `statd` and `lockd` ports used
    in NSM and NLM, respectively.
  * A unique `rpcbind` port per server is required in order for a NFS client
    to be able tunnel its server-specific RPC requests to the appropriate
    server.

Despite this limitation, this module still fully supports unencrypted NFSv3
and allows the NFS server and client to use unencrypted NFSv3 concurrently
with stunneled NFSv4.

* If a NFS server is configured to both allow NFSv3 and to use stunnel,
  it will accept unencrypted NFSv3 connections, unencrypted NFSv4
  connections and stunneled NFSv4 connections.

  The hieradata for this configuration is:

  ``` yaml
  nfs::is_server: true
  nfs::nfsv3: true
  nfs::stunnel: true
  ```

* If a NFS client is configured to both allow NFSv3 and to use stunnel,
  it can use unencrypted NFSv3 mounts and stunneled NFSv4 mounts.

  The hieradata for this configuration is:

  ``` yaml
  nfs::nfsv3: true
  nfs::stunnel: true
  ```

### Other security features

This module can be configured to automatically add firewall rules and allow
NFS services in TCP wrappers using the
[SIMP `iptables` module](https://github.com/simp/pupmod-simp-iptables) and the
[SIMP `tcpwrappers` module](https://github.com/simp/pupmod-simp-tcpwrappers),
respectively.

To enable these features on the NFS server and NFS client nodes, add the
following to their hieradata:

``` yaml
simp_options::firewall: true
simp_options::tcpwrappers: true
```

## Reference

Please refer to the [REFERENCE.md](./REFERENCE.md).

## Limitations

This module does not yet manage the following:

* `/etc/nfsmounts.conf`
* `gssproxy` configuration

  * If you are using a custom keytab location, you must fix the `cred_store`
    entries in `/etc/gssproxy/24-nfs-server.conf` and
    `/etc/gssproxy/99-nfs-client.conf`.
  * If a node's keytab has changed content and the old keytab entries
    are no longer valid, you will have to manually clear the `gssproxy`
    credential cache using `kdestroy -c <gssproxy cache>`.
    Simply restarting the `gssproxy` service does not clear the cache
    and re-read the keytab!

* RDMA packages or its service
* `idmapd` configuration for the `umich_ldap` translation method

  * If you need to configure this, consider using `nfs::idmapd::config::content`
    to specify full contents of the `/etc/idmapd.conf` file.

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux
and compatible distributions, such as CentOS. Please see the [`metadata.json` file](./metadata.json)
for the most up-to-date list of supported operating systems, Puppet versions,
and module dependencies.

## Development

Please read our [Contribution Guide](https://simp.readthedocs.io/en/stable/contributors_guide/index.html).

### Acceptance tests

This module includes [Beaker](https://github.com/puppetlabs/beaker) acceptance
tests using the SIMP [Beaker Helpers](https://github.com/simp/rubygem-simp-beaker-helpers).
By default the tests use [Vagrant](https://www.vagrantup.com/) with
[VirtualBox](https://www.virtualbox.org) as a back-end; Vagrant and VirtualBox
must both be installed to run these tests without modification. To execute the
tests run the following:

```shell
bundle install
bundle exec rake beaker:suites
```

Please refer to the [SIMP Beaker Helpers documentation](https://github.com/simp/rubygem-simp-beaker-helpers/blob/master/README.md) for more information.
