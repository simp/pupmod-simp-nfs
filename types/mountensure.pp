# Ensure for non-autofs mounts
type Nfs::MountEnsure = Enum[
  'mounted',
  'present',
  'unmounted'
]
