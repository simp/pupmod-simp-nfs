module Acceptance::Helpers::ManifestHelpers
  # returns Hash of NFS host-specific hieradata
  #
  # +base_hiera+: Hash of base hieradata
  # +opts+: Hash of host-specific hieradata to be added
  #
  def build_host_hiera(base_hiera, opts)
    hiera = Marshal.load(Marshal.dump(base_hiera))
    hiera['nfs::is_client'] = opts[:is_client]
    hiera['nfs::is_server'] = opts[:is_server]
    hiera['nfs::nfsv3'] = opts[:nfsv3]
    hiera['nfs::nfsd_port'] = opts[:nfsd_port]
    hiera['nfs::stunnel_nfsd_port'] = opts[:stunnel_nfsd_port]
    hiera.compact
  end

  # Create a string that can be inserted into the body of a
  # nfs::client::mount in a manifest and which contains custom mount
  # options
  def build_custom_mount_options(opts)
    options = ''
    if opts[:mount_nfs_version]
      options += "  nfs_version => #{opts[:mount_nfs_version]},\n"
    end

    if opts[:mount_sec]
      options += "  sec         => #{opts[:mount_sec]},\n"
    end

    unless opts[:mount_autodetect_remote].nil?
      options += if opts[:mount_autodetect_remote]
                   "  autodetect_remote => true,\n"
                 else
                   "  autodetect_remote => false,\n"
                 end
    end

    if opts[:mount_nfsd_port]
      options += "  nfsd_port   => #{opts[:mount_nfsd_port]},\n"
    end

    if opts[:mount_stunnel_nfsd_port]
      options += "  stunnel_nfsd_port => #{opts[:mount_stunnel_nfsd_port]},\n"
    end

    unless opts[:mount_stunnel].nil?
      options += if opts[:mount_stunnel]
                   "  stunnel     => true,\n"
                 else
                   "  stunnel     => false,\n"
                 end
    end

    options
  end

  # Create a manifest that creates a directory, creates a test file in
  # that directory, and then exports the directory
  def create_export_manifest(opts)
    <<~EOM
      include 'ssh'

      file { '#{opts[:exported_dir]}':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
      }

      file { '#{opts[:exported_file]}':
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => "#{opts[:exported_file_content]}\\n",
      }

      nfs::server::export { '#{opts[:exported_dir]}':
        clients     => ['*'],
        export_path => '#{opts[:exported_dir]}',
        sec         => ['#{opts[:export_sec]}'],
        insecure    => #{opts[:export_insecure]},
      }

      File['#{opts[:exported_dir]}'] -> Nfs::Server::Export['#{opts[:exported_dir]}']

      #{opts[:server_custom]}
    EOM
  end

  # Create a manifest that creates a mount directory and then statically
  # mounts to that directory
  def create_static_mount_manifest(opts)
    custom_mount_options = build_custom_mount_options(opts)

    <<~EOM
      include 'ssh'

      nfs::client::mount { '#{opts[:mount_dir]}':
        nfs_server  => '#{opts[:mount_server_ip]}',
        remote_path => '#{opts[:mount_remote_dir]}',
        autofs      => false,
      #{custom_mount_options}
      }

      # mount directory must exist if not using autofs
      file { '#{opts[:mount_dir]}':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
      }

      File['#{opts[:mount_dir]}'] -> Nfs::Client::Mount['#{opts[:mount_dir]}']
    EOM
  end

  def print_test_config(hieradata, manifest)
    puts '>' * 80
    if hieradata.is_a?(Hash)
      puts "Hieradata:\n#{hieradata.to_yaml}"
    else
      puts "Hieradata:\n#{hieradata}"
    end
    puts '-' * 80
    puts "Manifest:\n#{manifest}"
    puts '<' * 80
  end
end
