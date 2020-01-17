# @summary Manage the `idmapd` client configuration
#
# When using `idmapd`, an NFSv4 client uses `nfsidmap`, directly, instead
# of `nfs-idmapd.service`. `nfsidmap` is configured by `/etc/idmapd.conf`,
# but must be hooked into `/sbin/request-key` via `/etc/request-key.conf`.
#
# @param timeout
#   `nfsidmap` key expiration timeout in seconds
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::idmapd::client(
  Integer[0] $timeout = 600
) {

  include 'nfs::idmapd::config'

  # TODO write an augeas lens
  $_key_conf = '/etc/request-key.conf'
  $_new_line = "create\tid_resolver\t*\t*\t\t/usr/sbin/nfsidmap -t ${timeout} %k %d"
  $_remove_cmd = "/usr/bin/sed -r -i '/^create[[:space:]]+id_resolver[[:space:]]/d' ${_key_conf}"
  $_insert_cmd = "/usr/bin/sed -i '/^negate/i ${_new_line}' ${_key_conf}"
  exec { 'enable_nfsidmap_request_key':
    unless  => "/usr/bin/grep -v '#' /etc/request-key.conf | grep -q 'nfsidmap -t ${timeout}'",
    command => "${_remove_cmd};${_insert_cmd}"
  }
}
