require 'json'

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
        # build hash of data
        {}
      end

      def commit(action, request)
        data = ssl_post(SERVICE_URLS[action], request)
        response = parse_response(action, data)
        Response.new(response["success"], "message", response)
      end

      def parse_response(action, json)
        JSON.parse(json)
      end

    end
  end
end
