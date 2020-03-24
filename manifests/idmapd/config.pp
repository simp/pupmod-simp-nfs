# @summary Manage `idmapd` configuration
#
# @see idmapd.conf(5)
#
# @param verbosity
# @param domain
# @param no_strip
# @param reformat_group
# @param local_realms
# @param nobody_user
# @param nobody_group
# @param trans_method
#   `[Translation]` Method
#
#   * `Method` is a reserved word in Ruby
#   * `umich_ldap` is not yet supported
#
# @param gss_methods
# @param static_translation
#   Will be translated into the `[Static]` section variables as presented in
#   the man page
#
#   * For example: `{ 'foo' => 'bar' }` will be `foo = bar` in the output file
#
# @param content
#   Use this as the explicit content for the `idmapd` configuration file
#
#   * Overrides **all** other options
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::idmapd::config (
  Optional[Integer]                            $verbosity          = undef,
  Optional[String[1]]                          $domain             = undef,
  Optional[Enum['user','group','both','none']] $no_strip           = undef,
  Optional[Boolean]                            $reformat_group     = undef,
  Optional[Array[String[1],1]]                 $local_realms       = undef,
  String                                       $nobody_user        = 'nobody',
  String                                       $nobody_group       = 'nobody',
  Array[Enum['nsswitch','static'],1]           $trans_method       = ['nsswitch'],
  Optional[Array[Enum['nsswitch','static'],1]] $gss_methods        = undef,
  Optional[Hash[String[1],String[1]]]          $static_translation = undef,
  Optional[String]                             $content            = undef
) {

  file { '/etc/idmapd.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp("${module_name}/etc/idmapd.conf.epp")
  }
}
