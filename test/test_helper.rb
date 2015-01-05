require 'bundler/setup'

require 'active_fulfillment'

require 'minitest/autorun'
require 'mocha/setup'
require 'timecop'

require 'logger'
ActiveFulfillment::Service.logger = Logger.new(nil)

module ActiveFulfillment::Test
  module Fixtures
    LOCAL_CREDENTIALS = ENV['HOME'] + '/.active_fulfillment/fixtures.yml' unless defined?(LOCAL_CREDENTIALS)
    DEFAULT_CREDENTIALS = File.dirname(__FILE__) + '/fixtures.yml' unless defined?(DEFAULT_CREDENTIALS)

    def fixtures(key)
      data = all_fixtures[key] || raise(StandardError, "No fixture data was found for '#{key}'")

      data.dup
    end

    def xml_fixture(path) # where path is like 'usps/beverly_hills_to_ottawa_response'
      File.read(File.join(File.dirname(__FILE__),'fixtures','xml',"#{path}.xml"))
    end

    private

    def all_fixtures
      @@fixtures ||= load_fixtures
    end

    def load_fixtures
      file = File.exists?(LOCAL_CREDENTIALS) ? LOCAL_CREDENTIALS : DEFAULT_CREDENTIALS
      YAML.load(File.read(file)).deep_symbolize_keys
    end
  end
end
