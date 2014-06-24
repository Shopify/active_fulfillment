require 'json'
require 'cgi'

module ActiveMerchant
  module Fulfillment
    class JamesAndJamesService < Service

      SERVICE_URLS = {
        fulfillment: 'https://%{subdomain}.sixworks.co.uk/api/1/',
        inventory: 'https://%{subdomain}.sixworks.co.uk/api/1/stock'
      }

      def initialize(options = {})
        requires!(options, :subdomain, :key)
        super
      end

      def fulfill(order_id, shipping_address, line_items, options = {})
        commit :fulfillment, build_fulfillment_request(order_id, shipping_address, line_items, options)
      end

      def fetch_stock_levels(options = {})
        get :inventory, build_inventory_request(options)
      end

      private

      def build_fulfillment_request(order_id, shipping_address, line_items, options)
        data = {
          order: {
            client_ref: order_id,
            ShippingContact: format_address(shipping_address),
            BillingContact: format_address(shipping_address),
            items: format_line_items(line_items)
          }
        }
        data[:allow_preorder] = options[:allow_preorder] unless options[:allow_preorder].blank?
        data[:update_stock] = options[:update_stock] unless options[:update_stock].blank?
        data[:order][:po_number] = options[:po_number] unless options[:po_number].blank?
        data[:order][:date_placed] = options[:date_placed] unless options[:po_number].blank?
        return data
      end

      def build_inventory_request(options)
        {}
      end

      def commit(action, request)
        request = request.merge({api_key: @options[:key], test: true})
        data = ssl_post(SERVICE_URLS[action] % {subdomain: @options[:subdomain]}, JSON.generate(request))
        response = parse_response(action, data)
        Response.new(response["success"], "message", response, test: response["test"])
      end

      def get(action, request)
        request = request.merge({api_key: @options[:key], test: true})
        data = ssl_get(SERVICE_URLS[action] % {subdomain: @options[:subdomain]} + "?" + request.to_query)
        response = parse_response(action, data)
        Response.new(response["success"], "message", response, test: response["test"])
      end

      def parse_response(action, json)
        JSON.parse(json)
      end

      def format_address(address)
        data = {
          name: address[:name],
          address: address[:address1],
          city: address[:city],
          country: address[:country],
          postcode: address[:zip]
        }
        data[:company] = address[:company] unless address[:company].blank?
        data[:email] = address[:email] unless address[:email].blank?
        data[:address_contd] = address[:address2] unless address[:address2].blank?
        data[:country] = address[:state] unless address[:state].blank?
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
end
