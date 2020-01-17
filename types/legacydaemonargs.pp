# Legacy NFS daemon *ARGS environment variables set in /etc/sysconfig/nfs and
# automatically converted to the environment variables needed by the daemons
# in their service scripts by /usr/lib/systemd/scripts/nfs-utils_env.sh
type Nfs::LegacyDaemonArgs = Struct[{
  Optional['GSSDARGS']      => String,
  Optional['RPCIDMAPDARGS'] => String,
  Optional['RPCMOUNTDARGS'] => String,
  Optional['RPCNFSDARGS']   => String,
  Optional['SMNOTIFYARGS']  => String,
  # This is converted to STATDARGS
  Optional['STATDARG']      => String
}]

