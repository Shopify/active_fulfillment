require 'json'
require 'cgi'

module ActiveMerchant
  module Fulfillment
    class JamesAndJamesService < Service

      SERVICE_URLS = {
        fulfillment: 'https://test.sixworks.co.uk/api/1/'
      }

      def initialize(options = {})
        requires!(options, :key)
        super
      end

      def fulfill(order_id, shipping_address, line_items, options = {})
        commit :fulfillment, build_fulfillment_request(order_id, shipping_address, line_items, options)
      end

      private

      def build_fulfillment_request(order_id, shipping_address, line_items, options)
        {
          client_ref: order_id,
          ShippingContact: format_address(shipping_address),
          BillingContact: format_address(shipping_address),
          items: format_line_items(line_items)
        }
      end

      def commit(action, data)
        request = {api_key: @options[:key], test: true, order: data}
        data = ssl_post(SERVICE_URLS[action], JSON.generate(request))
        response = parse_response(action, data)
        Response.new(response["success"], "message", response)
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
