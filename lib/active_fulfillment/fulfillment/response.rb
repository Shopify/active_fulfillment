module ActiveMerchant
  module Fulfillment
  
    class Error < StandardError
    end
  
    class Response
      attr_reader :params
      attr_reader :message
      attr_reader :test
    
      def success?
        @success
      end

      def test?
        @test
      end
        
      def initialize(success, message, params = {}, options = {})
        @success, @message, @params = success, message, params.stringify_keys
        @test = options[:test] || false        
      end
      
      def method_missing(method, *args)
        @params[method.to_s] || super
      end
    end
  end
end