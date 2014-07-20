module ActiveMerchant
  module Fulfillment
    class ShopifyAPIService < Service

      def initialize(options={})
        @format = options[:format]
        @domain = options[:domain]
        @callback_url = options[:callback_url]
        @api_permission = options[:api_permission]
        @name = options[:name]
      end

      def fulfill(order_id, shipping_address, line_items, options = {})
        raise NotImplementedError.new("Shopify API Service must listen to fulfillment/create Webhooks")
      end

      def fetch_stock_levels(options = {})
        response = send_app_request('fetch_stock', options.slice(:sku))
        # this should return an unsucessful response
        #raise FulfillmentError, "Unable to fetch remote stock levels" unless response
        stock_levels = parse_response(response, 'StockLevels', 'Product', 'Sku', 'Quantity') { |p| p.to_i }

        Response.new(true, "API stock levels", {:stock_levels => stock_levels})
      end

      def fetch_tracking_data(order_ids, options = {})
        response = send_app_request('fetch_tracking_numbers', {:order_ids => order_ids})
        # this should return an unsucessful response
        #raise FulfillmentError, "Unable to fetch remote tracking numbers #{order_ids.inspect}" unless response
        tracking_numbers = parse_response(response, 'TrackingNumbers', 'Order', 'ID', 'Tracking') { |o| o }

        Response.new(true, "API tracking_numbers", {:tracking_numbers => tracking_numbers,
                                                    :tracking_companies => {},
                                                    :tracking_urls => {}})
      end

      private

      def request_uri(action, data)
        data['timestamp'] = Time.now.utc.to_i
        data['shop'] = @domain

        URI.parse "#{@callback_url}/#{action}.#{@format}?#{data.to_param}"
      end

      def send_app_request(action, data)
        uri = request_uri(action, data)
        logger.info "[" + @name.upcase + " APP] Post #{uri}"

        response = nil
        realtime = Benchmark.realtime do
          begin
            Timeout.timeout(20.seconds) do
              response = ssl_get(uri, headers(data.to_param))
            end
          # this line needs to change because this is shopify specific constants
          rescue *(NetHTTPExceptions + [Net::HTTP::SSLError, ActiveMerchant::ConnectionError, ActiveMerchant::ResponseError]) => e
            logger.warn "[#{self}] Error while contacting fulfillment service error =\"#{e.message}\""
          end
        end

        line = "[" + @name.upcase + "APP] Response from #{uri} --> "
        line << "#{response} #{"%.4fs" % realtime}"
        logger.info line

        response
      end

      def parse_response(response, root, type, key, value)
        case @format
        when 'json'
          response_data = ActiveSupport::JSON.decode(response)
          response_data[root.underscore] || response_data
        when 'xml'
          response_data = {}
          document = REXML::Document.new(response)
          document.elements[root].each do |node|
            if node.name == type
              response_data[node.elements[key].text] = node.elements[value].text
            end
          end
          response_data
        end

      rescue ActiveSupport::JSON.parse_error, REXML::ParseException
        {}
      end

      def encode_payload(payload, root)
        case @format
        when 'json'
          {root => payload}.to_json
        when 'xml'
          payload.to_xml(:root => root)
        end
      end

      def headers(data)
        {
          'X-Shopify-Shop-Domain' => @domain,
          'X-Shopify-Hmac-SHA256' => @api_permission.api_client.hmac(data),
          'Content-Type'          => "application/#{@format}"
        }
      end

    end
  end
end
