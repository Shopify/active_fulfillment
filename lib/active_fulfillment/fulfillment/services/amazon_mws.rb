require 'base64'
require 'openssl'
require 'time'
require 'cgi'

module ActiveMerchant
  module Fulfillment
    class AmazonMarketplaceWebService < Service

      APPLICATION_IDENTIFIER = "active_merchant_mws/0.01 (Language=ruby)"

      SIGNATURE_VERSION = 2
      SIGNATURE_METHOD  = "SHA256"
      VERSION = "2011-01-01"

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
          :zip => "DestinationAddress.PostalCode"
        },
        :line_items => {
          :comment => "Item.member.%d.DisplayableComment",
          :gift_message => "Item.member.%d.GiftMessage",
          :currency_code => "Item.member.%d.PerUnitDeclaredValue.CurrencyCode",
          :value => "Item.member.%d.PerUnitDeclaredValue.Value",
          :quantity => "Item.member.%d.Quantity",
          :order_id => "Item.member.%d.SellerFulfillmentOrderItemId",
          :sku => "Item.member.%d.SellerSKU",
          :network_sku => "Item.member.%d.FulfillmentNetworkSKU",
          :item_disposition => "Item.member.%d.OrderItemDisposition"
        }
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
          :list_next => 'ListInventorySupply'
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
      
      def self.sign(aws_secret_access_key, auth_string)
        Base64.encode64(OpenSSL::HMAC.digest(@@digest, aws_secret_access_key, auth_string)).strip
      end

      def initialize(options = {})
        requires!(options, :login, :password)
        options
        super
      end

      def endpoint
        ENDPOINTS[@options[:endpoint] || :us]
      end

      def fulfill(order_id, shipping_address, line_items, options = {})
        requires!(options, :order_date, :comment, :shipping_method)
        commit :post, :outbound, :create, build_fulfillment_request(order_id, shipping_address, line_items, options)
      end

      def commit(verb, service, op, params)
        uri = URI.parse("#{endpoint}/#{OPERATIONS[service][op]}/#{VERSION}")
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
      end

      def parse_fulfillment_response(op, document)
        response = {}
        action = OPERATIONS[:outbound][op]
        node = REXML::XPath.first(document, "//#{action}Response")

        response[:response_status]  = SUCCESS
        response[:response_comment] = MESSAGES[op][SUCCESS]
        response
      end

      def parse_inventory_response(document)
      end

      def sign(http_verb, uri, options)
        opts = build_basic_api_query(options)
        string_to_sign = "#{http_verb.to_s.upcase}\n"
        string_to_sign += "#{uri.host}\n"
        string_to_sign += uri.path.length <= 0 ? "/\n" : "#{uri.path}\n"
        string_to_sign += build_query(options)
        
        # remove trailing newline created by encode64
        Base64.encode64(OpenSSL::HMAC.digest(SIGNATURE_METHOD, @options[:password], string_to_sign)).chomp
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
        opts
      end

      def build_fulfillment_request(order_id, shipping_address, line_items, options)
        params = {
          :Action => OPERATIONS[:outbound][:create],
          :SellerFulfillmentOrderId => order_id.to_s,
          :DisplayableOrderId => order_id.to_s
        }
        request = build_basic_api_query(params.merge(options))
        request.merge build_address(shipping_address)
        request.merge build_items(line_items)

        request
      end

      def build_address(address)
        requires!(address, :name, :address1, :city, :state, :country, :zip)
        ary = address.map{ |key, value|
          [escape(LOOKUPS[:destination_address][key]), escape(value.to_s)]
        }
        Hash[ary]
      end

      def build_items(line_items)
        counter = 0
        line_items.reduce({}) do |items, line_item|
          counter += 1
          line_item.keys.reduce(items) do |hash, key|
            entry = escape(LOOKUPS[:line_items][key] % counter)
            hash[entry] = escape(line_item[key].to_s)
            hash
          end
        end
      end

      def escape(str)
        CGI.escape(str).gsub('+', '%20')
      end
    end
  end
end
