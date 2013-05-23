#!/usr/bin/env ruby
$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'rubygems'
require 'bundler'
Bundler.setup

require 'minitest/autorun'
require 'digest/md5'
require 'active_fulfillment'
require 'active_utils'

require 'mocha/setup'

module Minitest
  class Test
    include ActiveMerchant::Fulfillment
    
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
  end
end

class ActiveMerchant::Fulfillment::Test < Minitest::Test; end
