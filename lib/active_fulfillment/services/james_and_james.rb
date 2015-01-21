require 'json'

module ActiveFulfillment
  class JamesAndJamesService < Service

    FULFILLMENT_URL = 'https://%{subdomain}.sixworks.co.uk/api/1/'
    INVENTORY_URL = 'https://%{subdomain}.sixworks.co.uk/api/1/stock'

    def initialize(options = {})
      requires!(options, :subdomain, :key)
      super
    end

    def fulfill(order_id, shipping_address, line_items, options = {})
      requires!(options, :billing_address)
      request = build_fulfillment_request(order_id, shipping_address, line_items, options)
      request = request.merge({api_key: @options[:key], test: test? })

      data = ssl_post(FULFILLMENT_URL % {subdomain: @options[:subdomain]}, JSON.generate(request))
      response = JSON.parse(data)
      FulfillmentResponse.new(response["success"], "message", response, test: response["test"])

    rescue ActiveUtils::ResponseError => e
      response = parse_error(e.response)
      FulfillmentResponse.new(false, response[:http_message], response)
    rescue JSON::ParserError => e
      FulfillmentResponse.new(false, e.message)
    end

    def fetch_all_stock_levels(options = {})
      request = {api_key: @options[:key], test: test? }

      data = ssl_get(INVENTORY_URL % {subdomain: @options[:subdomain]} + "?" + request.to_query)
      response = JSON.parse(data)
      Response.new(response["success"], "message", response, test: response["test"])

    rescue ActiveUtils::ResponseError => e
      response = parse_error(e.response)
      StockLevelsResponse.new(false, response[:http_message], response)
    rescue JSON::ParserError => e
      StockLevelsResponse.new(false, e.message)
    end

    def supports_test_mode?
      true
    end

    private

    def build_fulfillment_request(order_id, shipping_address, line_items, options)
      data = {
        order: {
          client_ref: order_id,
          ShippingContact: format_address(shipping_address),
          BillingContact: format_address(options[:billing_address]),
          items: format_line_items(line_items)
        }
      }
      data[:allow_preorder] = options[:allow_preorder] unless options[:allow_preorder].blank?
      data[:update_stock] = options[:update_stock] unless options[:update_stock].blank?
      data[:order][:po_number] = options[:po_number] unless options[:po_number].blank?
      data[:order][:date_placed] = options[:date_placed] unless options[:po_number].blank?
      data[:order][:postage_speed] = options[:postage_speed] unless options[:postage_speed].blank?
      data[:order][:postage_cost] = options[:postage_cost] unless options[:postage_cost].blank?
      data[:order][:total_value] = options[:total_value] unless options[:total_value].blank?
      data[:order][:days_before_bbe] = options[:days_before_bbe] unless options[:days_before_bbe].blank?
      data[:order][:callback_url] = options[:callback_url] unless options[:callback_url].blank?
      return data
    end

    def parse_error(http_response)
      response = {}
      response[:http_code] = http_response.code
      response[:http_message] = http_response.message
      response
    end

    def format_address(address)
      data = {
        name: address[:name],
        address: address[:address1],
        city: address[:city],
        country: address[:country],
        postcode: address[:zip].blank? ? "-" : address[:zip]
      }
      data[:company] = address[:company] unless address[:company].blank?
      data[:email] = address[:email] unless address[:email].blank?
      data[:address_contd] = address[:address2] unless address[:address2].blank?
      data[:county] = address[:state] unless address[:state].blank?
      return data
    end

    def format_line_items(items)
      data = []
      items.each do |item|
        data << {
          client_ref: item[:sku],
          quantity: item[:quantity],
          price: item[:price]
        }
      end
      return data
    end

  end
end
