require 'bundler/setup'

require 'minitest/autorun'
require 'digest/md5'
require 'active_fulfillment'
require 'active_utils'
require 'timecop'

require 'mocha/setup'

require 'logger'
ActiveFulfillment::Service.logger = Logger.new(nil)

module Test
  module Unit
    class TestCase < Minitest::Test
      include ActiveFulfillment

      LOCAL_CREDENTIALS = ENV['HOME'] + '/.active_merchant/fixtures.yml' unless defined?(LOCAL_CREDENTIALS)
      DEFAULT_CREDENTIALS = File.dirname(__FILE__) + '/fixtures.yml' unless defined?(DEFAULT_CREDENTIALS)

      def all_fixtures
        @@fixtures ||= load_fixtures
      end

      def fixtures(key)
        data = all_fixtures[key] || raise(StandardError, "No fixture data was found for '#{key}'")

        data.dup
      end

      def load_fixtures
        file = File.exists?(LOCAL_CREDENTIALS) ? LOCAL_CREDENTIALS : DEFAULT_CREDENTIALS
        yaml_data = YAML.load(File.read(file))
        symbolize_keys(yaml_data)

        yaml_data
      end

      def xml_fixture(path) # where path is like 'usps/beverly_hills_to_ottawa_response'
        open(File.join(File.dirname(__FILE__),'fixtures','xml',"#{path}.xml")) {|f| f.read}
      end

      def symbolize_keys(hash)
        return unless hash.is_a?(Hash)

        hash.symbolize_keys!
        hash.each{|k,v| symbolize_keys(v)}
      end

      def assert_raise(error)
        begin
          yield
        rescue => e
          flunk "Expected #{error} but nothing raised" if e.class != error
        end
      end

      def assert_nothing_raised
        yield
      end
    end
  end
end
