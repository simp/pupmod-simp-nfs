[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html) [![Build Status](https://travis-ci.org/simp/pupmod-simp-nfs.svg)](https://travis-ci.org/simp/pupmod-simp-nfs) [![SIMP compatibility](https://img.shields.io/badge/SIMP%20compatibility-4.2.*%2F5.1.*-orange.svg)](https://img.shields.io/badge/SIMP%20compatibility-4.2.*%2F5.1.*-orange.svg)


#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with nfs](#setup)
    * [Setup requirements](#setup-requirements)
    * [Beginning with nfs](#beginning-with-nfs)
3. [Usage - Configuration options and additional functionality](#usage)
    * [Basic Usage](#basic-usage)
    * [Usage with krb5](#usage-with-krb5)
    * [Automatic mounting of home directories](#automatic-mounting-of-home-directories)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
    * [Acceptance Tests - Beaker env variables](#acceptance-tests)


## Description

The SIMP nfs module can manage the exporting and mounting of nfs devices. It provides all the infrastructure needed to share a folder over the network.

The module is broken into two parts: the server and the client. It supports security with either krb5 or stunnel, but not both. The services conflict at a system level.


### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://github.com/NationalSecurityAgency/SIMP), a compliance-management framework built on Puppet.

If you find any issues, they may be submitted to our [bug tracker](https://simp-project.atlassian.net/).

This module is optimally designed for use within a larger SIMP ecosystem, but it can be used independently:

 * When included within the SIMP ecosystem, security compliance settings will be managed from the Puppet server.
 * If used independently, all SIMP-managed security subsystems are disabled by default and must be explicitly opted into by administrators.  Please review the `$client_nets`, `$enable_*` and `$use_*` parameters in `manifests/init.pp` for details.


## Setup


### Setup Requirements

The only thing necessary to begin using nfs is to install pupmod-simp-nfs and pupmod-simp-autofs into your modulepath.


### Beginning with nfs

To get started with this module, a few settings have to be set in hiera.

To be applied to all nodes, in `default.yaml`:

``` yaml
nfs::server: "your.server.fqdn"
nfs::server::client_ips: "%{alias('client_nets')}"
nfs::simp_iptables: true
```

On the node intended to be the server:

``` yaml
nfs::is_server: true

classes:
  - 'site::nfs_server'
```

On a node intended to be a client:

``` yaml
classes:
  - 'site::nfs_client'
```

## Usage


### Basic Usage

In order to export `/srv/nfs_share` and mount it as `/mnt/nfs` on a client,
you need to create a couple of profile classes.

One to be added to the node intended to be the server, to define the exported path:

``` puppet
class site::nfs_server (
  $usekrb5 = hiera('nfs::simp_krb5',false),
  $client_nets = defined('$::client_nets') ? { true => $::client_nets,default => hiera('client_nets') },
  ){
  include '::nfs'

  if $usekrb5 {
    $security = 'krb5p'
  } else {
    $security = 'sys'
  }

  include '::nfs'

  file { '/srv/nfs_share':
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0644'
  }

  nfs::server::export { 'nfs4_root':
    client      => $client_nets,
    export_path => '/srv/nfs_share',
    sec         => ["${security}"],
    require     => File['/srv/nfs_share']
  }
}
```

And another profile class to be added to a node intended to be a client, to mount the exported filesystem on a node. Note that all that is needed is the native Puppet `mount` resource:

``` puppet
class site::nfs_client (
    $usekrb5 = hiera('nfs::simp_krb5',false),
  ){
  include '::nfs'

  if $usekrb5 {
    $security = 'krb5p'
  } else {
    $security = 'sys'
  }


  file { '/mnt/nfs':
    ensure => 'directory',
    mode => '755',
    owner => 'root',
    group => 'root'
  }

  mount { "/mnt/nfs":
    ensure  => 'mounted',
    fstype  => 'nfs4',
    device  => '<your_server_fqdn>:/srv/nfs_share',
    options => "sec=${security}",
    require => File['/mnt/nfs']
  }
}
```


### Usage with krb5

WARNING! This functionality requires some manual configuration and is largely untested.

This module, used with the [SIMP krb5 module](https://github.com/simp/pupmod-simp-krb5), can automatically use kerberos to secure the exported filesystem. The module can create and manage the entire kerberos configuration automatically, but check the krb5 module itself if you want more control.

Modify the examples provided above to include the following hieradata:

To be applied on every node in `default.yaml`:

``` yaml
simp_krb5: true

nfs::secure_nfs: true

krb5::kdc::auto_keytabs::global_services:
  - 'nfs'
```

On the node intended to be the server, add `krb5::kdc` to the class list:

``` yaml
classes:
  - 'krb5::kdc'
```

Add the following entry to both your site::nfs_server and site::nfs_client
manifests replacing <class_name> with the correct class name (either nfs_sever
or nfs_client)

```puppet
Class['krb5::keytab'] -> Class['site::<class_name>']

# if your realm is not your domain name then change this
# to the string that is your realm
myrealm = inline_template('<%= @domain.upcase %>')

krb5::setting::realm { ${myrealm}:
  admin_server => hiera('puppet::server'),
  default_domain => ${myrealm}
}

```

Further changes that must be made because of outstanding bugs:

In SIMP-5.1.X, set the following selinux context or the rpc.svcgssd
service will not run on any server using kerberos:

```bash
touch /tmp/gssd.te
```

Add the following to /tmp/gssd.te

```bash
module krb_svcgssd 1.0;

require {
	type krb_conf_t;
	type gssd_t;
	class dir read;
}

#=============== gssd_t =================
allow gssd_t krb5_conf_t:dir read;
```
then run:

```bash
/bin/checkmodule -M -m -o krb_svcgssd.mod /tmp/gssd.te
```

SIMP does not have kerberos set up to work automatically with LDAP yet.
You must add a pricipal for  each user you want to give access to the krb5 protected
directories.  To do this log onto the KDC and run:

```bash
kadmin.local
#note the prompt is now kadmin.local
kadmin.local:  add_principal -pw <password> <username>
...
kadmin.local:  exit
```
When the user logs on after kerberos has been configured they must run:

```bash
kinit
```
It will ask them for their password.  Once the have done this they should be
able to access any shares from that realm.

If you get an error that it can't access the profile, that means that the
configuration files in /etc/krb5.conf.d and /etc/krb5.conf.simp.d and
/etc/krb5.conf are not world readable.

### Automatic mounting of home directories

Please reference the [SIMP documentation](http://simp.readthedocs.io/en/master/user_guide/HOWTO/NFS.html#exporting-home-directories) for details on how to implement this feature.


## Limitations

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux and compatible distributions, such as CentOS. Please see the [`metadata.json` file](./metadata.json) for the most up-to-date list of supported operating systems, Puppet versions, and module dependencies.


## Development

Please read our [Contribution Guide](https://simp-project.atlassian.net/wiki/display/SD/Contributing+to+SIMP) and visit our [developer wiki](https://simp-project.atlassian.net/wiki/display/SD/SIMP+Development+Home).


### Acceptance tests

This module includes [Beaker](https://github.com/puppetlabs/beaker) acceptance tests using the SIMP [Beaker Helpers](https://github.com/simp/rubygem-simp-beaker-helpers).  By default the tests use [Vagrant](https://www.vagrantup.com/) with [VirtualBox](https://www.virtualbox.org) as a back-end; Vagrant and VirtualBox must both be installed to run these tests without modification. To execute the tests run the following:

```shell
bundle install
bundle exec rake beaker:suites
```

Please refer to the [SIMP Beaker Helpers documentation](https://github.com/simp/rubygem-simp-beaker-helpers/blob/master/README.md) for more information.
