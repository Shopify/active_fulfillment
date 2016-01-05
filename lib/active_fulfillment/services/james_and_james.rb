require 'json'

module ActiveFulfillment
  class JamesAndJamesService < Service

    SERVICE_URLS = {
      fulfillment: 'https://%{subdomain}.sixworks.co.uk/api/1/',
      inventory: 'https://%{subdomain}.sixworks.co.uk/api/1/stock'
    }.freeze

    def initialize(options = {})
      requires!(options, :subdomain, :key)
      super
    end

    def fulfill(order_id, shipping_address, line_items, options = {})
      requires!(options, :billing_address)
      commit :fulfillment, build_fulfillment_request(order_id, shipping_address, line_items, options)
    end

    def fetch_stock_levels(options = {})
      get :inventory, build_inventory_request(options)
    end

    def test_mode?
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

    def build_inventory_request(options)
      {}
    end

    def commit(action, request)
      request = request.merge({api_key: @options[:key], test: test? })
      data = ssl_post(SERVICE_URLS[action] % {subdomain: @options[:subdomain]}, JSON.generate(request))
      response = parse_response(data)
      Response.new(response["success"], "message", response, test: response["test"])
    rescue ActiveUtils::ResponseError => e
      handle_error(e)
    rescue JSON::ParserError => e
      Response.new(false, e.message)
    end

    def get(action, request)
      request = request.merge({api_key: @options[:key], test: test? })
      data = ssl_get(SERVICE_URLS[action] % {subdomain: @options[:subdomain]} + "?" + request.to_query)
      response = parse_response(data)
      Response.new(response["success"], "message", response, test: response["test"])
    rescue ActiveUtils::ResponseError => e
      handle_error(e)
    rescue JSON::ParserError => e
      Response.new(false, e.message)
    end

    def parse_response(json)
      JSON.parse(json)
    end

    def handle_error(e)
      response = parse_error(e.response)
      Response.new(false, response[:http_message], response)
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
