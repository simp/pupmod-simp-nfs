# @summary NFS server firewall configuration
#
# @api private
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::server::firewall
{
  assert_private()

  if $nfs::server::stunnel {
    # NFSv4 stunnel will take care of opening the firewall for its port

    if $nfs::server::nfsd_vers3 {
      # NFSv3 is not stunneled
      contain 'nfs::server::firewall::nfsv3and4'
    }
  } elsif $nfs::server::nfsd_vers3 {
    contain 'nfs::server::firewall::nfsv3and4'
  } else {
    contain 'nfs::server::firewall::nfsv4'
  }
}
