module ActiveFulfillment
  class Service

    include ActiveUtils::RequiresParameters
    include ActiveUtils::PostsData

    class_attribute :logger

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

    def valid_credentials?
      true
    end

    # Fulfill an order.
    #
    # @example
    #
    #     carrier = ActiveFulfillment::Carrier.new(...)
    #     response = carrier.fulfill(order.id, order.shipping_address, order.line_items)
    #     assert response.success?
    #
    #
    # @param order_id [String] Unique identifier for the order
    # @param shipping_address [?] The address to ship the order to
    # @param line_items [?] The line items to include in the order.
    # @param options [Hash] Service-specific options.
    #
    # @return [ActiveFulfillment::FulfillResponse]
    # @note This should be implemented by concrete subclasses.
    def fulfill(order_id, shipping_address, line_items, options = {})
      raise NotImplementedError.new("Subclasses must implement")
    end

    # Retrieve stock levels for a single SKU that the fulfillment service stocks.
    # The stock levels will be returned as a Hash-like object, indexed by SKU.
    #
    # @param sku [Array<String>] The SKUs to retreive. All the provided skus
    #   must be set as a key in the response object.
    # @param options [Hash] Service-specific options.
    # @return [ActiveFulfillment::StockLevelResponse]
    # @note This should be implemented by concrete subclasses.
    def fetch_stock_levels(skus, options = {})
      fetch_all_stock_levels(options)
    end

    # Retrieve stock levels for all SKUs that the fulfillment service stocks.
    # The stock levels will be returned as a Hash-like object, indexed by SKU.
    #
    # @example
    #
    #     carrier = ActiveFulfillment::Carrier.new(...)
    #     stock_levels = carrier.fetch_all_stock_levels
    #     stock_levels.each { |sku, stock| ... }
    #
    # @param options [Hash] Service-specific options.
    # @return [ActiveFulfillment::StockLevelResponse]
    # @note This should be implemented by concrete subclasses.
    def fetch_all_stock_levels(options = {})
      raise NotImplementedError.new("Subclasses must implement")
    end

    # Method to retrieve tracking data for a list of orders.
    #
    # @example
    #
    #     carrier = ActiveFulfillment::Carrier.new(...)
    #     tracking_data = carrier.fetch_tracking_data([order.id])
    #     tracking_data['order_id'].tracking_code
    #     tracking_data['order_id'].tracking_url
    #     tracking_data['order_id'].company
    #
    # @param options [Array<String>] A list of order IDs for which to retrieve tracking options.
    # @param options [Hash] Service-specific options.
    # @return [ActiveFulfillment::TrackingDataResponse]
    # @note This should be implemented by concrete subclasses.
    def fetch_tracking_data(order_ids, options = {})
      raise NotImplementedError.new("Subclasses must implement")
    end


    def fetch_tracking_numbers(order_ids, options = {})
      response = fetch_tracking_data(order_ids, options)
      response.params.delete('tracking_companies')
      response.params.delete('tracking_urls')
      response
    end

    private

    def check_test_mode(options)
      if options[:test] and not test_mode?
        raise ArgumentError, 'Test mode is not supported by this gateway'
      end
    end
  end
end
