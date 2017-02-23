require 'active_support/core_ext/object/to_query'
require 'resolv'

module ActiveFulfillment
  class ShopifyAPIService < Service

    OrderIdCutoffDate = Date.iso8601('2015-03-01').freeze

    RESCUABLE_CONNECTION_ERRORS = [
      Net::ReadTimeout,
      Net::OpenTimeout,
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
    ].freeze

    def initialize(options = {})
      @name = options[:name]
      @callback_url = options[:callback_url]
      @format = options[:format]
    end

    def fulfill(order_id, shipping_address, line_items, options = {})
      raise NotImplementedError.new('Shopify API Service must listen to fulfillment/create Webhooks'.freeze)
    end

    def fetch_stock_levels(options = {})
      response = send_app_request('fetch_stock'.freeze, options.delete(:headers), options)
      if response
        stock_levels = parse_response(response, 'StockLevels'.freeze, 'Product'.freeze, 'Sku'.freeze, 'Quantity'.freeze) { |p| p.to_i }
        Response.new(true, 'API stock levels'.freeze, {:stock_levels => stock_levels})
      else
        Response.new(false, 'Unable to fetch remote stock levels'.freeze)
      end
    end

    def fetch_tracking_data(order_numbers, options = {})
      options.merge!({:order_names => order_numbers})
      response = send_app_request('fetch_tracking_numbers'.freeze, options.delete(:headers), options)
      if response
        tracking_numbers = parse_response(response, 'TrackingNumbers'.freeze, 'Order'.freeze, 'ID'.freeze, 'Tracking'.freeze) { |o| o }
        Response.new(true, 'API tracking_numbers'.freeze, {:tracking_numbers => tracking_numbers,
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

      log :info, "GET action=#{action}"
      log :debug, "GET url=#{uri}"

      response = nil
      realtime = Benchmark.realtime do
        begin
          Timeout.timeout(20.seconds) do
            response = ssl_get(uri, headers)
          end
        rescue *(RESCUABLE_CONNECTION_ERRORS) => e
          log :warn, "Error contacting fulfillment service exception=\"#{e.class}\" message=\"#{e.message}\""
        end
      end

      log :info, "GET response action=#{action} in #{"%.4fs" % realtime} #{response}"

      response
    end

    def parse_json(json_data, root)
      response_data = ActiveSupport::JSON.decode(json_data)
      return {} unless response_data.is_a?(Hash)
      response_data[root.underscore] || response_data
    rescue ActiveSupport::JSON.parse_error
      {}
    end

    def parse_xml(xml_data, type, key, value)
      Parsing.with_xml_document(xml_data) do |document, response|
        # Extract All elements of type and map them!
        root_element = document.xpath("//#{type}")
        root_element.each do |type_item|
          key_item = type_item.at_css(key).child.content
          value_item = type_item.at_css(value).child.content
          response[key_item] = value_item
        end
        response
      end
    end

    def parse_response(response, root, type, key, value)
      return parse_json(response, root) if @format == 'json'.freeze
      return parse_xml(response, type, key, value) if @format == 'xml'.freeze
      {}
    end

    def encode_payload(payload, root)
      case @format
      when 'json'.freeze
        {root => payload}.to_json
      when 'xml'.freeze
        payload.to_xml(:root => root)
      end
    end

    def log(level, message)
      logger.public_send(level, "[ActiveFulfillment::ShopifyAPIService][#{@name.upcase} app] #{message}")
    end
  end
end
