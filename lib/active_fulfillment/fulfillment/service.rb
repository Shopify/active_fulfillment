module ActiveMerchant
  module Fulfillment
    class Service
      
      include RequiresParameters
      include PostsData
      
      def initialize(options = {})
        check_test_mode(options)
        
        @options = {}
        @options.update(options)
      end
      
      def test_mode?
        false
      end
      
      def test?
        @options[:test] || Base.mode == :test
      end
      
      private
      def check_test_mode(options)
        if options[:test] and not test_mode?
          raise ArgumentError, 'Test mode is not supported by this gateway'
        end
      end
    end
  end
end