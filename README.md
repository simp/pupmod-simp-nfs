[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html) [![Build Status](https://travis-ci.org/simp/pupmod-simp-nfs.svg)](https://travis-ci.org/simp/pupmod-simp-nfs) [![SIMP compatibility](https://img.shields.io/badge/SIMP%20compatibility-4.2.*%2F5.1.*-orange.svg)](https://img.shields.io/badge/SIMP%20compatibility-4.2.*%2F5.1.*-orange.svg)


#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with nfs](#setup)
    * [Setup requirements](#setup-requirements)
    * [Beginning with nfs](#beginning-with-nfs)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
    * [Acceptance Tests - Beaker env variables](#acceptance-tests)


## Description

**FIXME:** Ensure the *Description* section is correct and complete, then remove this message!

The SIMP nfs module can manage the exporting and mounting of nfs devices. It provides all the infrastructure needed to share a folder over the network.

The module is broken into two parts: the server and the client. It supports security with either krb5 or stunnel, but not both.


### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://github.com/NationalSecurityAgency/SIMP), a compliance-management framework built on Puppet.

If you find any issues, they may be submitted to our [bug tracker](https://simp-project.atlassian.net/).

This module is optimally designed for use within a larger SIMP ecosystem, but it can be used independently:

 * When included within the SIMP ecosystem, security compliance settings will be managed from the Puppet server.
 * If used independently, all SIMP-managed security subsystems are disabled by default and must be explicitly opted into by administrators.  Please review the `$client_nets`, `$enable_*` and `$use_*` parameters in `manifests/init.pp` for details.


## Setup


### Setup Requirements

The only thing necessary to begin using nfs is to install it into your modulepath.


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

In order to export a directory on an nfs server, you need to create a profile class:

``` puppet
class site::nfs_server {
  include '::nfs'

  file { '/srv/nfs_share':
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0644'
  }

  nfs::server::export { 'nfs4_root':
    client      => ['*'],
    export_path => '/srv/nfs_share',
    sec         => ['sys'],
    require     => File['/srv/nfs_share']
  }
}
```

And another one to mount the exported filesystem on a node. Note that all that is needed is the native Puppet `mount` resource:

``` puppet
class site::nfs_client {
  include '::nfs'

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
    options => 'sec=sys'
    require => File['/mnt/nfs']
  }
}
```


### Usage with krb5

This module, used with the [SIMP krb5 module](https://github.com/simp/pupmod-simp-krb5), can automatically use kerberos to secure the exported filesystem. The module can create and manage the entire kerberos configuration automatically, but check the krb5 module itself if you want more control.

Change the examples provided above to include the following hieradata:

To be applied on every node in `default.yaml`:

``` yaml
simp_krb5: true

nfs::server: "your.server.fqdn"
nfs::server::client_ips: "%{alias('client_nets')}"
nfs::simp_iptables: true
nfs::secure_nfs: true

krb5::kdc::auto_keytabs::global_services:
  - 'nfs'
```

On the node intended to be the server:

``` yaml
nfs::is_server: true

classes:
  - 'site::nfs_server'
  - 'krb5::kdc'
```

On a node intended to be a client:

``` yaml
classes:
  - 'site::nfs_client'
```


### Automatic mounting of home directories

Please reference the [SIMP documentation](http://simp.readthedocs.io/en/master/user_guide/HOWTO/NFS.html#exporting-home-directories) for details on how to implement this feature.


## Limitations

**FIXME:** Ensure the *Limitations* section is correct and complete, then remove this message!

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux and compatible distributions, such as CentOS. Please see the [`metadata.json` file](./metadata.json) for the most up-to-date list of supported operating systems, Puppet versions, and module dependencies.


## Development

Please read our [Contribution Guide](https://simp-project.atlassian.net/wiki/display/SD/Contributing+to+SIMP) and visit our [developer wiki](https://simp-project.atlassian.net/wiki/display/SD/SIMP+Development+Home).


### Acceptance tests

This module includes [Beaker](https://github.com/puppetlabs/beaker) acceptance tests using the SIMP [Beaker Helpers](https://github.com/simp/rubygem-simp-beaker-helpers).  By default the tests use [Vagrant](https://www.vagrantup.com/) with [VirtualBox](https://www.virtualbox.org) as a back-end; Vagrant and VirtualBox must both be installed to run these tests without modification. To execute the tests run the following:

```shell
bundle install
bundle exec rake beaker:suites
```

**FIXME:** Ensure the *Acceptance tests* section is correct and complete, including any module-specific instructions, and remove this message!

Please refer to the [SIMP Beaker Helpers documentation](https://github.com/simp/rubygem-simp-beaker-helpers/blob/master/README.md) for more information.
