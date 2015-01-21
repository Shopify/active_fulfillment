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

    def supports_test_mode?
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
    #     service = ActiveFulfillment::Service.new(...)
    #     response = service.fulfill(order.id, order.shipping_address, order.line_items)
    #     assert response.success?
    #
    #
    # @param [String] order_id Unique identifier for the order
    #
    # @param [Hash] shipping_address The address to ship the order to
    # @option shipping_address [String] :name
    # @option shipping_address [String] :company
    # @option shipping_address [String] :address1
    # @option shipping_address [String] :address2
    # @option shipping_address [String] :phone
    # @option shipping_address [String] :city
    # @option shipping_address [String] :state
    # @option shipping_address [String] :country
    # @option shipping_address [String] :zip
    #
    # @param [Array<Hash>] line_items The line items to include in the order.
    # @option line_items [String] :sku
    # @option line_items [String] :quantity
    # @option line_items [String] :description
    # @option line_items [String] :value
    # @option line_items [String] :currency_code
    #
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
    # @param [Array<String>] sku The SKUs to retreive. All the provided skus
    # must be set as a key in the response object.
    # @param [Hash] options Service-specific options.
    #
    # @return [ActiveFulfillment::StockLevelResponse]
    # @note This should be implemented by concrete subclasses.
    def fetch_stock_levels(skus, options = {})
      raise NotImplementedError, "Subclasses must implement"
    end

    # Retrieve stock levels for all SKUs that the fulfillment service stocks.
    # The stock levels will be returned as a Hash-like object, indexed by SKU.
    #
    # @example
    #
    #     service = ActiveFulfillment::Service.new(...)
    #     stock_levels = service.fetch_all_stock_levels
    #     stock_levels.each { |sku, stock| ... }
    #
    # @param [Hash] options Service-specific options.
    #
    # @return [ActiveFulfillment::StockLevelResponse]
    # @note This should be implemented by concrete subclasses.
    def fetch_all_stock_levels(options = {})
      raise NotImplementedError.new("Subclasses must implement")
    end

    # Method to retrieve tracking data for a list of orders.
    #
    # @example
    #
    #     service = ActiveFulfillment::Service.new(...)
    #     tracking_data = service.fetch_tracking_data([order.id])
    #     tracking_data['order_id'].tracking_code
    #     tracking_data['order_id'].tracking_url
    #     tracking_data['order_id'].company
    #
    # @param [Array<String>] order_ids A list of order IDs for which to retrieve tracking options.
    # @param [Hash] options Service-specific options.
    #
    # @return [ActiveFulfillment::TrackingDataResponse]
    # @note This should be implemented by concrete subclasses.
    def fetch_tracking_number(order_ids, options = {})
      raise NotImplementedError.new("Subclasses must implement")
    end

    private

    def check_test_mode(options)
      if options[:test] && !supports_test_mode?
        raise ArgumentError, 'Test mode is not supported by this gateway'
      end
    end
  end
end
