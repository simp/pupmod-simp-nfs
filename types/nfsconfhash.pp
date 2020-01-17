# Hash representing nfs.conf configuration in which the key is the section
# name and the value is a Hash of key/value options for that section.
type Nfs::NfsConfHash = Struct[{
  Optional['general']     => Hash[String,Variant[Boolean,Integer,Float,String]],
  Optional['exportfs']    => Hash[String,Variant[Boolean,Integer,Float,String]],
  Optional['gssd']        => Hash[String,Variant[Boolean,Integer,Float,String]],
  Optional['lockd']       => Hash[String,Variant[Boolean,Integer,Float,String]],
  Optional['mountd']      => Hash[String,Variant[Boolean,Integer,Float,String]],
  Optional['nfsd']        => Hash[String,Variant[Boolean,Integer,Float,String]],
  Optional['nfsdcltrack'] => Hash[String,Variant[Boolean,Integer,Float,String]],
  Optional['sm-notify']   => Hash[String,Variant[Boolean,Integer,Float,String]],
  Optional['statd']       => Hash[String,Variant[Boolean,Integer,Float,String]]
}]

