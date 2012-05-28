require 'base64'
require 'time'
require 'cgi'

module ActiveMerchant
  module Fulfillment
    class AmazonMarketplaceWebService < Service

      APPLICATION_IDENTIFIER = "active_merchant_mws/0.01 (Language=ruby)"

      REGISTRATION_URI = URI.parse("https://sellercentral.amazon.com/gp/mws/registration/register.html")

      SIGNATURE_VERSION = 2
      SIGNATURE_METHOD  = "SHA256"
      VERSION = "2010-10-01"

      SUCCESS, FAILURE, ERROR = 'Accepted', 'Failure', 'Error'

      MESSAGES = {
        :status => {
          'Accepted' => 'Success',
          'Failure'  => 'Failed',
          'Error'    => 'An error occurred'          
        },
        :create => {
          'Accepted' => 'Successfully submitted the order',
          'Failure'  => 'Failed to submit the order',
          'Error'    => 'An error occurred while submitting the order'
        },
        :list   => {
          'Accepted' => 'Successfully submitted request',
          'Failure'  => 'Failed to submit request',
          'Error'    => 'An error occurred while submitting request'
          
        }
      }

      ENDPOINTS = {
        :ca => 'mws.amazonservices.ca',
        :cn => 'mws.amazonservices.com.cn',
        :de => 'mws-eu.amazonservices.ca',
        :es => 'mws-eu.amazonservices.ca',
        :fr => 'mws-eu.amazonservices.ca',
        :it => 'mws-eu.amazonservices.ca',
        :jp => 'mws.amazonservices.jp',
        :uk => 'mws-eu.amazonservices.ca',
        :us => 'mws.amazonservices.com'
      }

      LOOKUPS = {
        :destination_address => {
          :name => "DestinationAddress.Name",
          :address1 => "DestinationAddress.Line1",
          :address2 => "DestinationAddress.Line2",
          :city => "DestinationAddress.City",
          :state => "DestinationAddress.StateOrProvinceCode",
          :country => "DestinationAddress.CountryCode",
          :zip => "DestinationAddress.PostalCode",
          :phone => "DestinationAddress.PhoneNumber"
        },
        :line_items => {
          :comment => "Items.member.%d.DisplayableComment",
          :gift_message => "Items.member.%d.GiftMessage",
          :currency_code => "Items.member.%d.PerUnitDeclaredValue.CurrencyCode",
          :value => "Items.member.%d.PerUnitDeclaredValue.Value",
          :quantity => "Items.member.%d.Quantity",
          :order_id => "Items.member.%d.SellerFulfillmentOrderItemId",
          :sku => "Items.member.%d.SellerSKU",
          :network_sku => "Items.member.%d.FulfillmentNetworkSKU",
          :item_disposition => "Items.member.%d.OrderItemDisposition",
        },
        :list_inventory => {
          :sku => "SellerSkus.member.%d"
        }
      }

      ACTIONS = {
        :outbound => "FulfillmentOutboundShipment",
        :inventory => "FulfillmentInventory"
      }

      OPERATIONS = {
        :outbound => {
          :status => 'GetServiceStatus',
          :create => 'CreateFulfillmentOrder',
          :list   => 'ListAllFulfillmentOrders',
          :tracking => 'GetFulfillmentOrder'
        },
        :inventory => {
          :get  => 'ListInventorySupply',
          :list => 'ListInventorySupply',
          :list_next => 'ListInventorySupplyByNextToken'
        }
      }

      # The first is the label, and the last is the code
      # Standard:  3-5 business days
      # Expedited: 2 business days
      # Priority:  1 business day
      def self.shipping_methods
        [ 
          [ 'Standard Shipping', 'Standard' ],
          [ 'Expedited Shipping', 'Expedited' ],
          [ 'Priority Shipping', 'Priority' ]
        ].inject(ActiveSupport::OrderedHash.new){|h, (k,v)| h[k] = v; h}
      end

      def initialize(options = {})
        requires!(options, :login, :password)
        @seller_id = options[:seller_id]
        super
      end

      def seller_id=(seller_id)
        @seller_id = seller_id
      end

      def endpoint
        ENDPOINTS[@options[:endpoint] || :us]
      end

      def fulfill(order_id, shipping_address, line_items, options = {})
        requires!(options, :order_date, :comment, :shipping_method)
        commit :post, :outbound, :create, build_fulfillment_request(order_id, shipping_address, line_items, options)
      end

      def status
        commit :post, :outbound, :status, build_status_request
      end

      def fetch_current_orders
        commit :post, :outbound, :status, build_get_current_fulfillment_orders_request
      end

      def fetch_stock_levels(options = {})
        options[:skus] = [options.delete(:sku)] if options.include?(:sku)
        response = commit :post, :inventory, :list, build_inventory_list_request(options)

        while token = response.params['next_token'] do
          next_page = commit :post, :inventory, :list_next, build_next_inventory_list_request(token)

          next_page.stock_levels.merge!(response.stock_levels)
          response = next_page
        end

        response
      end

      def fetch_tracking_numbers(order_ids, options = {})
        order_ids.reduce(nil) do |previous, order_id|
          response = commit :post, :outbound, :tracking, build_tracking_request(order_id, options)

          if !response.success?
            if response.faultstring.match(/^Requested order \'.+\' not found$/)
              response = Response.new(true, nil, {
                                        :status => SUCCESS,
                                        :tracking_numbers => {}
                                      })
            else
              return response
            end
          end

          response.tracking_numbers.merge!(previous.tracking_numbers) if previous
          response
        end
      end

      def valid_credentials?
        fetch_stock_levels.success?
      end

      def test_mode?
        false
      end

      def commit(verb, service, op, params)
        uri = URI.parse("https://#{endpoint}/#{ACTIONS[service]}/#{VERSION}")
        signature = sign(verb, uri, params)
        query = build_query(params) + "&Signature=#{signature}"
        headers = build_headers(query)

        data = ssl_post(uri.to_s, query, headers)
        response = parse_response(service, op, data)
        Response.new(success?(response), message_from(response), response)
      rescue ActiveMerchant::ResponseError => e
        response = parse_error(e.response)
        Response.new(false, message_from(response), response)
      end

      def success?(response)
        response[:response_status] == SUCCESS
      end

      def message_from(response)
        response[:response_message]
      end

      ## PARSING

      def parse_response(service, op, xml)
        begin
          document = REXML::Document.new(xml)
        rescue REXML::ParseException
          return { :success => FAILURE }
        end

        case service
        when :outbound
          case op
          when :tracking
            parse_tracking_response(document)
          else
            parse_fulfillment_response(op, document)
          end
        when :inventory
          parse_inventory_response(document)
        else
          raise ArgumentError, "Unknown service #{service}"
        end
      end

      def parse_tracking_response(document)
        response = {}
        response[:tracking_numbers] = {}

        tracking_node = REXML::XPath.first(document, "//FulfillmentShipmentPackage/member/TrackingNumber")
        if tracking_node
          id_node = REXML::XPath.first(document, "//FulfillmentOrder/SellerFulfillmentOrderId")
          response[:tracking_numbers][id_node.text.strip] = tracking_node.text.strip
        end

        response[:response_status] = SUCCESS
        response
      end

      def parse_fulfillment_response(op, document)
        { :response_status => SUCCESS, :response_comment => MESSAGES[op][SUCCESS] }
      end

      def parse_inventory_response(document)
        response = {}
        response[:stock_levels] = {}

        document.each_element('//InventorySupplyList/member') do |node|
          params = node.elements.to_a.each_with_object({}) { |elem, hash| hash[elem.name] = elem.text }

          response[:stock_levels][params['SellerSKU']] = params['TotalSupplyQuantity'].to_i
        end
        
        next_token = REXML::XPath.first(document, '//NextToken')
        response[:next_token] = next_token ? next_token.text : nil
        
        response[:response_status] = SUCCESS
        response
      end

      def parse_error(http_response)
        response = {}
        response[:http_code] = http_response.code
        response[:http_message] = http_response.message

        document = REXML::Document.new(http_response.body)

        node = REXML::XPath.first(document, '//Error')
        error_code = REXML::XPath.first(node, '//Code')
        error_message = REXML::XPath.first(node, '//Message')

        response[:status] = FAILURE
        response[:faultcode] = error_code ? error_code.text : ""
        response[:faultstring] = error_message ? error_message.text : ""
        response[:response_message] = error_message ? error_message.text : ""
        response[:response_comment] = "#{response[:faultcode]}: #{response[:faultstring]}"
        response
      rescue REXML::ParseException => e
      rescue NoMethodError => e
        response[:http_body] = http_response.body
        response[:response_status] = FAILURE
        response[:response_comment] = "#{response[:http_code]}: #{response[:http_message]}"
        response
      end

      def sign(http_verb, uri, options)
        string_to_sign = "#{http_verb.to_s.upcase}\n"
        string_to_sign += "#{uri.host}\n"
        string_to_sign += uri.path.length <= 0 ? "/\n" : "#{uri.path}\n"
        string_to_sign += build_query(options)

        # remove trailing newline created by encode64
        escape(Base64.encode64(OpenSSL::HMAC.digest(SIGNATURE_METHOD, @options[:password], string_to_sign)).chomp)
      end

      def amazon_request?(signed_string, expected_signature)
        calculated_signature = escape(Base64.encode64(OpenSSL::HMAC.digest(SIGNATURE_METHOD, @options[:password], signed_string)).chomp)
        calculated_signature == expected_signature
      end

      def registration_url(options)
        opts = {
          "returnPathAndParameters" => options["returnPathAndParameters"],
          "id" => @options[:app_id],
          "AWSAccessKeyId" => @options[:login],
          "SignatureMethod" => "Hmac#{SIGNATURE_METHOD}",
          "SignatureVersion" => SIGNATURE_VERSION
        }
        signature = sign(:get, REGISTRATION_URI, opts)
        "#{REGISTRATION_URI.to_s}?#{build_query(opts)}&Signature=#{signature}"
      end

      def md5_content(content)
        Base64.encode64(OpenSSL::Digest::Digest.new('md5', content).digest).chomp
      end

      def build_query(query_params)
        query_params.sort.map{ |key, value| [escape(key.to_s), escape(value.to_s)].join('=') }.join('&')
      end

      def build_headers(querystr)
        {
          'User-Agent' => APPLICATION_IDENTIFIER,
          'Content-MD5' => md5_content(querystr),
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      end

      def build_basic_api_query(options)
        opts = Hash[options.map{ |k,v| [k.to_s, v.to_s] }]
        opts["AWSAccessKeyId"] = @options[:login] unless opts["AWSAccessKey"]
        opts["Timestamp"] = Time.now.utc.iso8601 unless opts["Timestamp"]
        opts["Version"] = VERSION unless opts["Version"]
        opts["SignatureMethod"] = "Hmac#{SIGNATURE_METHOD}" unless opts["SignatureMethod"]
        opts["SignatureVersion"] = SIGNATURE_VERSION unless opts["SignatureVersion"]
        opts["SellerId"] = @seller_id unless opts["SellerId"] || !@seller_id
        opts
      end

      def build_fulfillment_request(order_id, shipping_address, line_items, options)
        params = {
          :Action => OPERATIONS[:outbound][:create],
          :SellerFulfillmentOrderId => order_id.to_s,
          :DisplayableOrderId => order_id.to_s,
          :DisplayableOrderComment => options[:comment],
          :DisplayableOrderDateTime => options[:order_date].utc.iso8601,
          :ShippingSpeedCategory => options[:shipping_method]
        }
        request = build_basic_api_query(params.merge(options))
        request = request.merge build_address(shipping_address)
        request = request.merge build_items(line_items)

        request
      end

      def build_get_current_fulfillment_orders_request(options = {})
        start_time = options.delete(:start_time) || 1.day.ago.utc
        params = {
          :Action => OPERATIONS[:outbound][:list],
          :QueryStartDateTime => start_time.strftime("%Y-%m-%dT%H:%M:%SZ")
        }

        build_basic_api_query(params.merge(options))
      end

      def build_inventory_list_request(options = {})
        response_group = options.delete(:response_group) || "Basic"
        params = {
          :Action => OPERATIONS[:inventory][:list],
          :ResponseGroup => response_group
        }
        if skus = options.delete(:skus)
          skus.each_with_index do |sku, index|
            params[LOOKUPS[:list_inventory][:sku] % (index + 1)] = sku
          end
        else
          start_time = options.delete(:start_time) || 1.day.ago
          params[:QueryStartDateTime] = start_time.utc.iso8601
        end

        build_basic_api_query(params.merge(options))
      end

      def build_next_inventory_list_request(token)
        params = {
          :NextToken => token
        }
        
        build_basic_api_query(params)
      end

      def build_tracking_request(order_id, options)
        params = {:Action => OPERATIONS[:outbound][:tracking], :SellerFulfillmentOrderId => order_id}

        build_basic_api_query(params.merge(options))
      end

      def build_address(address)
        requires!(address, :name, :address1, :city, :state, :country, :zip)
        ary = address.map{ |key, value| [escape(LOOKUPS[:destination_address][key]), escape(value)] if value.length > 0 }
        Hash[ary.compact]
      end

      def build_items(line_items)
        lookup = LOOKUPS[:line_items]
        counter = 0
        line_items.reduce({}) do |items, line_item|
          counter += 1
          lookup.each do |key, value|
            entry = value % counter
            case key
            when :sku
              items[entry] = escape(line_item[:sku] || "SKU-#{counter}")
            when :order_id
              items[entry] = escape(line_item[:sku] || "FULFILLMENT-ITEM-ID-#{counter}")
            when :quantity
              items[entry] = escape(line_item[:quantity] || 1)
            else
              items[entry] = escape(line_item[key]) if line_item.include? key
            end
          end
          items
        end
      end

      def build_status_request
        build_basic_api_query({ :Action => OPERATIONS[:outbound][:status] })
      end

      def escape(str)
        CGI.escape(str.to_s).gsub('+', '%20')
      end
    end
  end
end
