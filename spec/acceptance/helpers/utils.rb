module Acceptance
  module Helpers
    module Utils

      # code copied from simp-core's acceptance tests
      # FIXME - Move to simp-beaker-helpers

      # @returns array of IPV4 networks configured on a host
      #
      # +host+: Host (object)
      #
      def host_networks(host)
        require 'json'
        require 'ipaddr'
        networking = JSON.load(on(host, 'facter --json networking').stdout)
        networking['networking']['interfaces'].delete_if { |key,value| key == 'lo' }
        networks = networking['networking']['interfaces'].map do |key,value|
          net_mask = IPAddr.new(value['netmask']).to_i.to_s(2).count("1")
          "#{value['network']}/#{net_mask}"
        end
        networks
      end

      # @returns the internal IPV4 network info for a host or nil if
      #   none can be found
      #
      # +host+: Host (object)
      #
      # This method ASSUMES the first non-loopback interface without DHCP
      # configured or with DHCP that does not matches the outermost 'dhcp'
      # key is the interface used for the internal network.
      def internal_network_info(host)
        networking = JSON.load(on(host, 'facter --json networking').stdout)
        internal_ip_info = nil
        main_dhcp = networking['networking']['dhcp']
        networking['networking']['interfaces'].each do |interface,settings|
          next if interface == 'lo'
          if ( ! settings.has_key?('dhcp') || (settings['dhcp'] != main_dhcp ) )
            internal_ip_info = {
              :interface => interface,
              :ip        => settings['ip'],
              :netmask   => settings['netmask']
            }
            break
          end
        end
        internal_ip_info
      end

      # Temporary hack to try to ensure connection to a host after reboot
      # with beaker 4.14.1
      # TODO: Remove this when beaker is fixed
      def wait_for_reboot_hack(host)
        # Sometimes beaker connects to the host before it has rebooted, so first sleep
        # to give the host time to get farther along in its shutdown
        wait_seconds = ENV['NFS_TEST_REBOOT_WAIT'] ?  ENV['NFS_TEST_REBOOT_WAIT'] : 10
        sleep(wait_seconds)

        # If beaker has already connected successfully before the reboot, it will think
        # the necessity to reconnect is a failure.  So it will close the connection and
        # raise an exception. If we catch that exception and retry, beaker will then
        # create a new connection.
        tries = ENV['NFS_TEST_RECONNECT_TRIES'] ?  ENV['NFS_TEST_RECONNECT_TRIES'] : 10
        begin
          on(host, 'uptime')
        rescue Beaker::Host::CommandFailure => e
          if e.message.include?('connection failure') && (tries > 0)
            puts "Retrying due to << #{e.message.strip} >>"
            tries -= 1
            sleep 1
            retry
          else
            raise e
          end
        end
      end
    end
  end
end
