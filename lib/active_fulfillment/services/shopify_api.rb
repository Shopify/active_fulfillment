require 'active_support/core_ext/object/to_query'

module ActiveFulfillment
  class ShopifyAPIService < Service

    OrderIdCutoffDate = Date.iso8601("2015-03-01")

    RESCUABLE_CONNECTION_ERRORS = [
      Net::ReadTimeout,
      Net::OpenTimeout,
      TimeoutError,
      Errno::ETIMEDOUT,
      Timeout::Error,
      IOError,
      EOFError,
      SocketError,
      Errno::ECONNRESET,
      Errno::ECONNABORTED,
      Errno::EPIPE,
      Errno::ECONNREFUSED,
      Errno::EAGAIN,
      Errno::EHOSTUNREACH,
      Errno::ENETUNREACH,
      Resolv::ResolvError,
      Net::HTTPBadResponse,
      Net::HTTPHeaderSyntaxError,
      Net::ProtocolError,
      ActiveUtils::ConnectionError,
      ActiveUtils::ResponseError,
      ActiveUtils::InvalidResponseError
    ]

    def initialize(options = {})
      @name = options[:name]
      @callback_url = options[:callback_url]
      @format = options[:format]
    end

    def fulfill(order_id, shipping_address, line_items, options = {})
      raise NotImplementedError.new("Shopify API Service must listen to fulfillment/create Webhooks")
    end

    def fetch_stock_levels(options = {})
      response = send_app_request('fetch_stock', options.delete(:headers), options)
      if response
        stock_levels = parse_response(response, 'StockLevels', 'Product', 'Sku', 'Quantity') { |p| p.to_i }
        Response.new(true, "API stock levels", {:stock_levels => stock_levels})
      else
        Response.new(false, "Unable to fetch remote stock levels")
      end
    end

    def fetch_tracking_data(order_numbers, options = {})
      options.merge!({:order_ids => order_numbers, :order_names => order_numbers})
      response = send_app_request('fetch_tracking_numbers', options.delete(:headers), options)
      if response
        tracking_numbers = parse_response(response, 'TrackingNumbers', 'Order', 'ID', 'Tracking') { |o| o }
        Response.new(true, "API tracking_numbers", {:tracking_numbers => tracking_numbers,
                                                    :tracking_companies => {},
                                                    :tracking_urls => {}})
      else
        Response.new(false, "Unable to fetch remote tracking numbers #{order_numbers.inspect}")
      end
    end

    private

    def request_uri(action, data)
      URI.parse "#{@callback_url}/#{action}.#{@format}?#{data.to_query}"
    end

    def send_app_request(action, headers, data)
      uri = request_uri(action, data)

      logger.info "[" + @name.upcase + " APP] Post #{uri}"

      response = nil
      realtime = Benchmark.realtime do
        begin
          Timeout.timeout(20.seconds) do
            response = ssl_get(uri, headers)
          end
        rescue *(RESCUABLE_CONNECTION_ERRORS) => e
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
        return {} unless response_data.is_a?(Hash)
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
  end
end
