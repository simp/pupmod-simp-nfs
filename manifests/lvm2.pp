# @summary Class to counterract a packaging bug with ``nfs-utils``.
#
# Unless ``lvm2`` is ensured latest, ``nfs-utils`` cannot upgrade.
# The class will be removed once the bug is fixed upstream.
#
# @param ensure
#    The ensure status of the lvm2 package
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::lvm2 (
  String $ensure = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'latest' }),
) {
  package { 'lvm2':
    ensure => $ensure
  }
}
