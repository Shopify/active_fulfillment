require 'bundler/setup'

require 'active_fulfillment'

require 'minitest/autorun'
require 'mocha/setup'
require 'timecop'

require 'logger'
ActiveFulfillment::Service.logger = Logger.new(nil)

# This makes sure that Minitest::Test exists when an older version of Minitest
# (i.e. 4.x) is required by ActiveSupport.
unless defined?(Minitest::Test)
  Minitest::Test = MiniTest::Unit::TestCase
end

module ActiveFulfillment::Test
  module Credentials
    def credentials(name)
      all_credentials[name.to_sym] or raise ArgumentError, "No credentials found for #{name}"
    end

    private

    def all_credentials
      @@all_credentials ||= begin
        file = File.exists?(LOCAL_CREDENTIALS) ? LOCAL_CREDENTIALS : DEFAULT_CREDENTIALS
        YAML.load(File.read(file)).deep_symbolize_keys
      end
    end

    LOCAL_CREDENTIALS = ENV['HOME'] + '/.active_fulfillment/credentials.yml'
    DEFAULT_CREDENTIALS = File.dirname(__FILE__) + '/credentials.yml'
    private_constant :LOCAL_CREDENTIALS, :DEFAULT_CREDENTIALS
  end

  module Fixtures
    def xml_fixture(path) # where path is like 'webgistic/beverly_hills_to_ottawa_response'
      File.read(File.join(File.dirname(__FILE__),'fixtures','xml',"#{path}.xml"))
    end
  end
end
