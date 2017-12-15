require 'spec_helper'

describe 'nfs::client::stunnel::v4' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:facts) { facts }

      let(:title) { 'my.nfs.server:1234' }

      it { is_expected.to compile.with_all_deps }
      it {
        is_expected.to create_stunnel__instance("nfs4_#{title}_client").with({
          :connect => ['my.nfs.server:20490'],
          :accept  => '127.0.0.1:1234'
        })
      }

=begin
## Can't do this yet
# https://github.com/rodjek/rspec-puppet/issues/310
      context 'when pointing at the local system' do
        let(:title) { "#{facts[:fqdn]}:1234" }

        before(:each) { scope.expects(:warning).returns(/You are trying to use.*direct connection/) }
        it { is_expected.to compile.with_all_deps }
      end
=end
    end
  end
end
