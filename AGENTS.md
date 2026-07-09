# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`simp-nfs` is a SIMP Puppet module that manages an **NFS server and/or NFS
client** on Enterprise Linux, including the optional PKI/`stunnel` and Kerberos
(`krb5`) integrations. It configures `/etc/nfs.conf` (and, on EL7, the legacy
`/etc/sysconfig/nfs`), installs the NFS packages, manages the NFS services,
`idmapd` name mapping, firewall openings, TCP wrappers, and — when Kerberos is
unavailable — can wrap critical NFSv4 connections in `stunnel`.

A single host can be a **server, a client, or both**. The entry class `nfs`
defaults to `is_client => true`, `is_server => false` (`manifests/init.pp:250-251`);
it always pulls in `nfs::install` and then conditionally includes `nfs::client`
and/or `nfs::server` (`init.pp:302-326`). The client and server branches share a
common base (`nfs::base::config` / `nfs::base::service`) but layer their own
config/service classes on top.

The public API is small: `include nfs` plus two defines — `nfs::client::mount`
(set up a client mount, optionally via autofs) and `nfs::server::export`
(add an `/etc/exports` entry). Both defines auto-`include` the relevant
orchestration class, so you can use them without explicitly declaring `nfs`.

### Business logic

#### Entry point (shared)

- **`nfs` (`manifests/init.pp:249-327`)** — Public entry class. **Not**
  `assert_private()`'d. Selects roles via `$is_server` / `$is_client`
  (`init.pp:250-251`), NFS version policy via `$nfsv3` (default `false`, i.e.
  NFSv4-only, `init.pp:252`), and the optional integrations `$kerberos`,
  `$firewall`, `$stunnel`, `$tcpwrappers` (each defaulted off the
  `simp_options::*` seam, `init.pp:269-277`). It runs
  `simplib::assert_metadata($module_name)` (`init.pp:285`), warns when the OS
  release is below `$minimum_os_version` (default `'7.4'`, `init.pp:286-288`),
  and guards each optional integration with
  `simplib::assert_optional_dependency` before use — `simp/iptables` when
  `$firewall` (`init.pp:290-292`), `simp/krb5` when `$kerberos`
  (`init.pp:294-296`), `simp/tcpwrappers` when `$tcpwrappers and
  $manage_tcpwrappers` (`init.pp:298-300`). Ordering: `nfs::selinux_hotfix` and
  `nfs::lvm2` (both optional) run **before** `nfs::install`, which runs before
  `nfs::client` / `nfs::server` (`init.pp:304-326`).
- **`nfs::install` (`manifests/install.pp:17-30`)** — private (`assert_private()`,
  `install.pp:22`). Installs `nfs-utils` and `nfs4-acl-tools`; installs
  `quota-rpc` only when `$nfs::is_server and $nfs::install_quota_rpc`
  (`install.pp:24-29`) — the latter flag is OS-data-driven (EL8+ only).
- **`nfs::base::config` / `nfs::base::service`** — private; the shared
  `/etc/nfs.conf` options and services common to client and server. `base::config`
  builds `$_required_nfs_conf_opts` and **deliberately overrides**
  `$nfs::custom_nfs_conf_opts` for those keys "because the firewall will not
  work otherwise" (`manifests/base/config.pp:12-15`).
- **`nfs::lvm2` (`manifests/lvm2.pp`)**, **`nfs::selinux_hotfix`
  (`manifests/selinux_hotfix.pp`)** — internal helper classes declared only by
  `nfs` (`init.pp:304-310`). `selinux_hotfix` is `assert_private()`'d
  (`selinux_hotfix.pp:11`); **`nfs::lvm2` is not** — it carries no
  `assert_private()`, so it is internal by convention only. The SELinux hotfix
  is an EL7+Kerberos-only workaround for a broken `selinux-policy`.

#### Client side

- **`nfs::client` (`manifests/client.pp:53-84`)** — private (`assert_private()`,
  `client.pp:62`), `inherits ::nfs`. Includes `nfs::base::config/service` and
  `nfs::client::config/service`, wiring notify (`~>`) ordering between them
  (`client.pp:64-71`). When `$nfs::kerberos`, includes `krb5` (and
  `krb5::keytab` when `$nfs::keytab_on_puppet`) ahead of the client service
  (`client.pp:73-83`).
- **`nfs::client::mount` (`manifests/client/mount.pp:185-346`)** — **PUBLIC
  define**; the main client-facing API. Title is the local mount path
  (validated as `Stdlib::Absolutepath`, `mount.pp:204-206`). `include`s
  `nfs::client` (`mount.pp:208`). Fails if `$nfs_version == 3` but
  `nfs::nfsv3` is false (`mount.pp:210-212`). Resolves per-mount overrides
  against the class defaults (`mount.pp:218-254`), builds the mount option
  string (`mount.pp:260-271`), and either creates an `autofs::map` (default,
  `$autofs => true`, guarded by `assert_optional_dependency($module_name,
  'simp/autofs')`, `mount.pp:292-331`) or a native `mount` resource
  (`mount.pp:333-345`). Always declares a
  `nfs::client::mount::connection` (`mount.pp:279-290`). Note: for NFSv3,
  stunnel is forced off (`mount.pp:224-225`); with stunnel or a
  self-mount it rewrites the remote to `127.0.0.1` (`mount.pp:273-277`).
- **`nfs::client::mount::connection`, `nfs::client::config`,
  `nfs::client::service`, `nfs::client::stunnel`, `nfs::client::tcpwrappers`** —
  all private. `client::stunnel` guards `simp/stunnel`
  (`manifests/client/stunnel.pp:68`).

#### Server side

- **`nfs::server` (`manifests/server.pp:117-173`)** — private (`assert_private()`,
  `server.pp:136`), `inherits ::nfs`. NFS-version policy lives here:
  `$nfsd_vers3` (defaults to `$nfs::nfsv3`), `$nfsd_vers4`, `$nfsd_vers4_0`
  (default `false`), `$nfsd_vers4_1`, `$nfsd_vers4_2` (`server.pp:118-122`).
  **Hard fail** when `$stunnel and $nfsd_vers4_0` — NFSv4.0 within stunnel is
  unsupported (`server.pp:138-140`). Includes base + server config/service +
  `nfs::idmapd::server`, and conditionally `nfs::server::stunnel` (when
  `$stunnel`), `nfs::server::firewall` (when `$nfs::firewall`), and `krb5` /
  `krb5::keytab` (when `$nfs::kerberos`) (`server.pp:142-172`).
- **`nfs::server::export` (`manifests/server/export.pp:121-168`)** — **PUBLIC
  define**; the main server-facing API. `include`s `nfs::server`
  (`export.pp:148`), emits a `concat::fragment` into `/etc/exports` from
  `templates/etc/export.erb` (`export.pp:150-155`), and — for `sec=sys` exports
  on SELinux-enabled hosts — sets the `nfsd_anon_write` selboolean
  (`export.pp:157-167`).
- **`nfs::server::config`, `nfs::server::service`, `nfs::server::stunnel`,
  `nfs::server::tcpwrappers`, `nfs::server::firewall`,
  `nfs::server::firewall::nfsv4`, `nfs::server::firewall::nfsv3and4`,
  `nfs::idmapd::server`** — all `assert_private()`'d. `server::stunnel` guards
  `simp/stunnel` (`manifests/server/stunnel.pp:33`).
- **`nfs::idmapd::client`, `nfs::idmapd::config` (`manifests/idmapd/`)** — the
  NFSv4 name-mapping helpers, declared only from within the module
  (`idmapd::client` from `nfs::client::config`, `client/config.pp:59`;
  `idmapd::config` from `nfs::base::config`, `base/config.pp:197`, and
  `nfs::idmapd::server`, `idmapd/server.pp:13`). Note these two carry **no**
  `assert_private()` (unlike `idmapd::server`), so they are private by
  convention only.

### Gotchas / non-obvious details

- **NFSv3 is off by default.** `nfs::nfsv3` defaults to `false`
  (`init.pp:252`), so only NFSv4 is allowed. A `nfs::client::mount` with
  `nfs_version => 3` **fails compilation** unless `nfs::nfsv3` is set true
  (`mount.pp:210-212`).
- **stunnel is incompatible with NFSv4.0.** `nfs::server` hard-`fail`s if
  `$stunnel and $nfsd_vers4_0` (`server.pp:138-140`); on the client side stunnel
  is silently disabled for NFSv3 mounts (`mount.pp:224-225`). stunnel only
  carries TCP and cannot wrap the NFSv4.0 delegation side channel.
- **`nfs::base::config` overrides your `custom_nfs_conf_opts`** for the keys it
  manages, on purpose — otherwise the firewall port openings do not line up
  (`base/config.pp:12-15`). Custom values for those sections/keys are lost.
- **OS-version behavior is driven by Hiera module data, not conditionals in the
  manifest.** `manage_tcpwrappers`, `install_quota_rpc`, `manage_sysconfig_nfs`,
  and `apply_selinux_hotfix` all default in `data/os/RedHat/<major>.yaml`:
  EL7 gets tcpwrappers + `sysconfig/nfs` + the SELinux hotfix; EL8+ drops
  tcpwrappers and `sysconfig/nfs` and instead installs `quota-rpc`
  (`data/os/RedHat/7.yaml`, `data/os/RedHat/8.yaml`, `data/os/RedHat/9.yaml`).
  The class defaults for these params in `init.pp:278-282` are conservative
  fallbacks that the data overrides.
- **Kerberos and stunnel are meant to be alternatives.** stunnel "is intended
  for environments without a working Kerberos setup and may cause issues when
  used with Kerberos" (`init.pp:156-160`). Prefer Kerberos.
- **Duplicate `/etc/exports` entries are allowed and the last one wins.** The
  `nfs::server::export` title must be unique but mountpoint+client is the only
  truly unique combination, so overlapping exports silently resolve to the last
  fragment (`export.pp:5-11`).
- **`insecure => true` is required for stunneled NFSv4 exports** due to a kernel
  export-rule-selection bug (`export.pp:24-34`,
  https://bugzilla.redhat.com/show_bug.cgi?id=1804912).
- **Optional integrations are guarded at runtime, not declared as hard deps.**
  `simp/iptables`, `simp/krb5`, `simp/tcpwrappers`, `simp/stunnel`, `simp/autofs`
  live in `metadata.json` `simp.optional_dependencies` and are asserted with
  `simplib::assert_optional_dependency` only on the code path that uses them
  (`init.pp:290-300`, `mount.pp:293`, `client/stunnel.pp:68`,
  `server/stunnel.pp:33`) — never hard-`include`d unconditionally.

## The `simp_options` / `simplib::lookup` seam

The SIMP feature-toggle seam is entirely in the class parameter defaults (the
two public defines have **no** `simplib::lookup` calls of their own). All calls:

| Line | Key | `default_value` |
|------|-----|-----------------|
| `init.pp:269` | `simp_options::kerberos` | `false` |
| `init.pp:270` | `simp_options::kerberos` | `true` |
| `init.pp:271` | `simp_options::firewall` | `false` |
| `init.pp:272` | `simp_options::stunnel` | `false` |
| `init.pp:276` | `simp_options::tcpwrappers` | `false` |
| `init.pp:277` | `simp_options::trusted_nets` | `['127.0.0.1']` |
| `install.pp:18` | `simp_options::package_ensure` | `'installed'` |
| `install.pp:19` | `simp_options::package_ensure` | `'installed'` |
| `install.pp:20` | `simp_options::package_ensure` | `'installed'` |
| `lvm2.pp:12` | `simp_options::package_ensure` | `'latest'` |

Keep routing SIMP feature toggles through `simplib::lookup('simp_options::*', {
'default_value' => ... })` with an explicit default rather than assuming
`simp_options` is included.

## Dependencies

Module dependencies (from `metadata.json`):

- `puppet/systemd` `>= 4.0.2 < 10.0.0` (systemd unit/service management)
- `puppet/augeasproviders_sysctl` `>= 2.4.0 < 4.0.0` (the `sysctl` type, for the
  sunrpc slot-table entries)
- `puppetlabs/concat` `>= 6.4.0 < 10.0.0` (builds `/etc/exports` and
  `/etc/nfs.conf` from fragments)
- `puppetlabs/stdlib` `>= 8.0.0 < 10.0.0` (stdlib types/functions)
- `simp/simplib` `>= 4.9.0 < 5.0.0` (provides `simplib::lookup`,
  `simplib::assert_metadata`, `simplib::assert_optional_dependency`,
  `simplib::host_is_me`, and the `Simplib::Port` / `Simplib::IP` /
  `Simplib::Netlist` types)
- `simp/svckill` `>= 3.6.1 < 4.0.0` (service reaping)
- `simp/vox_selinux` `>= 3.1.0 < 4.0.0` (SELinux management)

Optional dependencies (from `metadata.json` `simp.optional_dependencies`) —
asserted at runtime only on the code path that uses them:

- `simp/autofs` `>= 6.2.1 < 8.0.0` — `nfs::client::mount` with `autofs => true`.
- `simp/krb5` `>= 7.1.0 < 8.0.0` — Kerberos support.
- `simp/iptables` `>= 6.5.3 < 8.0.0` — firewall openings.
- `simp/stunnel` `>= 6.6.0 < 7.0.0` — stunnel-wrapped NFSv4.
- `simp/tcpwrappers` `>= 6.2.0 < 7.0.0` — TCP wrappers (EL7).

Fixture-only dependencies (from `.fixtures.yml`, present for test compilation,
not runtime deps): `augeas_core`, `augeasproviders_core`, `augeasproviders_grub`,
`augeasproviders_ssh`, `firewalld`, `haveged`, `mount_core`, `pki`,
`selinux_core`, `simp_firewalld`, `ssh` (plus the runtime and optional deps
above are also checked out as fixtures).

Runtime requirement (from `metadata.json` `requirements`): `puppet
>= 7.0.0 < 9.0.0`. (SIMP is migrating Puppet → OpenVox; when
`metadata.json` switches this to `openvox`, update this line to match.)

Supported OS matrix (from `metadata.json`): CentOS 7/8/9; RedHat 7/8/9;
OracleLinux 7/8/9; Rocky 8/9; AlmaLinux 8/9.

## Repository layout

- `manifests/init.pp` — the public `nfs` entry class (roles, options, optional
  integration guards, orchestration ordering).
- `manifests/install.pp`, `manifests/lvm2.pp`, `manifests/selinux_hotfix.pp` —
  shared install/helper classes.
- `manifests/base/{config,service}.pp` — config/services common to client &
  server.
- `manifests/client.pp` + `manifests/client/*` — client orchestration; public
  define `nfs::client::mount` (`manifests/client/mount.pp`); private
  `mount/connection.pp`, `config.pp`, `service.pp`, `stunnel.pp`,
  `tcpwrappers.pp`.
- `manifests/server.pp` + `manifests/server/*` — server orchestration; public
  define `nfs::server::export` (`manifests/server/export.pp`); private
  `config.pp`, `service.pp`, `stunnel.pp`, `tcpwrappers.pp`, `firewall.pp`,
  `firewall/nfsv4.pp`, `firewall/nfsv3and4.pp`.
- `manifests/idmapd/{client,config,server}.pp` — NFSv4 idmapd name mapping.
- `types/` — four custom data types: `Nfs::LegacyDaemonArgs`,
  `Nfs::MountEnsure`, `Nfs::NfsConfHash`, `Nfs::SecurityFlavor`.
- `templates/` — `etc/export.erb` (ERB), `etc/idmapd.conf.epp`,
  `etc/nfs_conf_section.epp` (EPP).
- `data/common.yaml`, `data/os/RedHat/{7,8,9}.yaml` — OS-version-driven defaults
  (`manage_tcpwrappers`, `install_quota_rpc`, `manage_sysconfig_nfs`,
  `apply_selinux_hotfix`, `minimum_os_version`); `hiera.yaml` is a v5 hierarchy
  keyed on `os.family`/`os.release.major`.
- `metadata.json` — deps, optional deps, OS matrix, Puppet requirement.
- `spec/` — rspec-puppet unit tests + beaker acceptance suites.
- `REFERENCE.md` — generated Puppet Strings reference.
- **No `lib/`** — this module ships no custom Ruby facts, functions, types, or
  providers; every custom function/fact/type it uses comes from the dependencies
  above (notably `simp/simplib`).

## Common commands

```sh
# Install dependencies
bundle install

# Run all unit tests
bundle exec rake spec

# Run a single class/define spec
bundle exec rspec spec/classes/init_spec.rb

# Puppet lint + metadata lint
bundle exec rake lint
bundle exec rake metadata_lint

# Ruby lint
bundle exec rake rubocop

# Regenerate REFERENCE.md from puppet-strings docstrings
puppet strings generate --format markdown --out REFERENCE.md

# Run a beaker acceptance suite (NOT run in CI — local/manual only)
bundle exec rake beaker:suites[default]
```

Relevant gem pins (from `Gemfile`): `puppetlabs_spec_helper ~> 8.0.0`,
`simp-rake-helpers ~> 5.24.0`, `simp-rspec-puppet-facts ~> 4.0.0`,
`simp-beaker-helpers ~> 2.0.0`. Rubocop is pinned to `~> 1.88.0`. The tested
Puppet range is `>= 7 < 9`. `spec/spec_helper.rb` uses
`require 'puppetlabs_spec_helper/module_spec_helper'`.

**Acceptance is NOT wired into CI.** `.github/workflows/pr_tests.yml` runs only
`puppet-syntax`, `puppet-style` (lint + metadata_lint), `ruby-style` (rubocop),
`file-checks`, `releng-checks` (tag/changelog + `pdk build`), and `spec-tests`
(rspec on Puppet 7.x and 8.x). There is **no** `acceptance:` job; the beaker
suites under `spec/acceptance/` are run locally/manually only.

## Conventions

- Preserve the `@summary` / `@param` puppet-strings docstrings — they drive
  `REFERENCE.md`. Regenerate `REFERENCE.md` after changing docs or parameters.
- Keep the two public entry points (`nfs::client::mount`,
  `nfs::server::export`) self-contained: each `include`s its orchestration class
  so consumers can use the define without declaring `nfs` first. Nearly all
  other classes are `assert_private()`'d — do not make them public. (The
  exceptions `nfs::lvm2`, `nfs::idmapd::client`, and `nfs::idmapd::config` omit
  `assert_private()` but are still internal-only; treat them as private too.)
- Keep OS-version differences in `data/os/RedHat/<major>.yaml`, not in manifest
  conditionals (that is how tcpwrappers/quota-rpc/sysconfig differences are
  handled today).
- Guard every optional integration (`autofs`, `krb5`, `iptables`, `stunnel`,
  `tcpwrappers`) with `simplib::assert_optional_dependency` and a parameter/fact
  check on the using code path — never hard-`include` an optional module.
- Continue routing SIMP feature toggles through
  `simplib::lookup('simp_options::*', { 'default_value' => ... })` rather than
  assuming `simp_options` is included.
- `Gemfile`, `spec/spec_helper.rb`, and `.github/workflows/pr_tests.yml` carry a
  **puppetsync** notice — they are baseline-managed and the next sync overwrites
  local edits. Push changes to those files upstream to the baseline, not here.
- Match the existing 2-space Puppet indentation and aligned-arrow parameter
  style used in the manifests.
