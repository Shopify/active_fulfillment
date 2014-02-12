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

      # API Requirements for Implementors
      def fulfill(order_id, shipping_address, line_items, options = {})
        raise NotImplementedError.new("Subclasses must implement")
      end

      def fetch_stock_levels(options = {})
        raise NotImplementedError.new("Subclasses must implement")
      end

      def fetch_stock_levels(options = {})
        raise NotImplementedError.new("Subclasses must implement")
      end

      def fetch_tracking_numbers(order_ids, options = {})
        raise NotImplementedError.new("Subclasses must implement")
      end

      def fetch_tracking_data(order_ids, options = {})
        raise NotImplementedError.new("Subclasses must implement")
      end

      def valid_credentials?
        raise NotImplementedError.new("Subclasses must implement")
      end

      def test_mode?
        raise NotImplementedError.new("Subclasses must implement")
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
