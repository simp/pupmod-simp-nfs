# @summary Manage the required NFS packages
#
# @param ensure
#    The ensure status of the nfs-utils package
#
# @param tools_ensure
#    The ensure status of the nfs4-acl-tools package
#
# @param quota_rpc_ensure
#    The ensure status of the quota-rpc package.  Only applies to the NFS server
#    on EL >7. Prior to EL8, rpc.rquotad files were included in the quota
#    package.
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::install (
  String $ensure           = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  String $tools_ensure     = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  String $quota_rpc_ensure = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
) {
  assert_private()

  package { 'nfs-utils': ensure => $ensure }
  package { 'nfs4-acl-tools': ensure => $tools_ensure }

  if $nfs::is_server and (versioncmp($facts['os']['release']['major'], '7') > 0) {
    package { 'quota-rpc': ensure => $quota_rpc_ensure }
  }
}
