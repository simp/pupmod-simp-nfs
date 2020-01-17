# Temporary workaround until ordering problem with firewalld module is fixed.
# FirewallBackend must be set to iptables in /etc/firewalld/firewalld.conf
# before the iptables rules from the NFS module are applied or nftables will
# be used and core dumps!  This leaves firewalld in a bad state which can include
# no rules loaded. Without the ssh rule loaded, ssh access is denied.
#
# Can't do this correctly with firewalld module yet.
shared_examples 'a firewalld fixer' do |hosts|
  hosts.each do |host|
    if host.hostname.start_with?('el8')
      it 'should turn off firewalld service' do
        on(host, 'puppet resource service firewalld ensure=stopped')
      end

      it 'should manually configure firewalld to use iptables backend' do
        on(host, "sed -i 's/FirewallBackend=nftables/FirewallBackend=iptables/' /etc/firewalld/firewalld.conf")

      end
    end
  end
end
