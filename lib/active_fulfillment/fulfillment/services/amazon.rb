require 'base64'
require 'openssl'

module ActiveMerchant
  module Fulfillment
    class AmazonService < Service
      SERVICES = {
        :outbound => {
          :url     => 'https://fba-outbound.amazonaws.com',
          :xmlns   => 'http://fba-outbound.amazonaws.com/doc/2007-08-02/',
          :version => '2007-08-02'
        },
        :inventory => {
          :url     => 'https://fba-inventory.amazonaws.com',
          :xmlns   => 'http://fba-inventory.amazonaws.com/doc/2009-07-31/',
          :version => '2009-07-31'          
        }
      }
    
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
      
      ENV_NAMESPACES = { 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                         'xmlns:env' => 'http://schemas.xmlsoap.org/soap/envelope/',
                         'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
                       }

      AWS_SECURITY_ATTRIBUTES = {
        "env:actor" => "http://schemas.xmlsoap.org/soap/actor/next",
        "env:mustUnderstand" => "0",
        "xmlns:aws" => "http://security.amazonaws.com/doc/2007-01-01/"
      }

      @@digest = OpenSSL::Digest::Digest.new("sha1")
      
      OPERATIONS = {
        :outbound => {
          :status => 'GetServiceStatus',
          :create => 'CreateFulfillmentOrder',
          :list   => 'ListAllFulfillmentOrders',
          :tracking => 'GetFulfillmentOrder'
        },
        :inventory => {
          :get  => 'GetInventorySupply',
          :list => 'ListUpdatedInventorySupply',
          :list_next => 'ListUpdatedInventorySupplyByNextToken'
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
        super
      end
      
      def status
        commit :outbound, :status, build_status_request
      end

      def fulfill(order_id, shipping_address, line_items, options = {})   
        requires!(options, :order_date, :comment, :shipping_method)
        commit :outbound, :create, build_fulfillment_request(order_id, shipping_address, line_items, options)
      end
      
      def fetch_current_orders
        commit :outbound, :list, build_get_current_fulfillment_orders_request
      end

      def fetch_stock_levels(options = {})
        if options[:sku]
          commit :inventory, :get, build_inventory_get_request(options)
        else
          response = commit :inventory, :list, build_inventory_list_request(options)

          while token = response.params['next_token'] do
            next_page = commit :inventory, :list_next, build_next_inventory_list_request(token)

            next_page.stock_levels.merge!(response.stock_levels)
            response = next_page
          end
          
          response
        end
      end

      def fetch_tracking_numbers(order_ids, options = {})
        order_ids.inject(nil) do |previous, o_id|
          response = commit :outbound, :tracking, build_tracking_request(o_id, options)

          if !response.success?
            if response.faultstring =~ /Reason: requested order not found./
              response = Response.new(true, nil, {
                :status           => SUCCESS,
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
        status.success?
      end
   
      def test_mode?
        false
      end

      private
      def soap_request(request)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! "env:Envelope", ENV_NAMESPACES do
          xml.tag! "env:Header" do
            add_credentials(xml, request)
          end
          xml.tag! "env:Body" do
            yield xml
          end
        end
        xml.target!
      end
      
      def build_status_request
        request = OPERATIONS[:outbound][:status]
        soap_request(request) do |xml|
          xml.tag! request, { 'xmlns' => SERVICES[:outbound][:xmlns] }
        end
      end
      
      def build_get_current_fulfillment_orders_request
        request = OPERATIONS[:outbound][:list]
        soap_request(request) do |xml|
          xml.tag! request, { 'xmlns' => SERVICES[:outbound][:xmlns] } do
            xml.tag! "NumberOfResultsRequested", 5
            xml.tag! "QueryStartDateTime", Time.now.utc.yesterday.strftime("%Y-%m-%dT%H:%M:%SZ")
          end
        end
      end

      def build_fulfillment_request(order_id, shipping_address, line_items, options)
        request = OPERATIONS[:outbound][:create]
        soap_request(request) do |xml|
          xml.tag! request, { 'xmlns' => SERVICES[:outbound][:xmlns] } do
            xml.tag! "MerchantFulfillmentOrderId", order_id
            xml.tag! "DisplayableOrderId", order_id
            xml.tag! "DisplayableOrderDateTime", options[:order_date].strftime("%Y-%m-%dT%H:%M:%SZ")
            xml.tag! "DisplayableOrderComment", options[:comment]
            xml.tag! "ShippingSpeedCategory", options[:shipping_method]
   
            add_address(xml, shipping_address)
            add_items(xml, line_items)
          end
        end
      end

      def build_inventory_get_request(options)
        request = OPERATIONS[:inventory][:get]
        soap_request(request) do |xml|
          xml.tag! request, { 'xmlns' => SERVICES[:inventory][:xmlns] } do
            xml.tag! "MerchantSKU", options[:sku]
            xml.tag! "ResponseGroup", "Basic"
          end
        end
      end

      def build_inventory_list_request(options)
        start_time = options[:start_time] || 1.day.ago

        request = OPERATIONS[:inventory][:list]
        soap_request(request) do |xml|
          xml.tag! request, { 'xmlns' => SERVICES[:inventory][:xmlns] } do
            xml.tag! "NumberOfResultsRequested", 50
            xml.tag! "QueryStartDateTime", start_time.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
            xml.tag! "ResponseGroup", "Basic"
          end
        end
      end

      def build_next_inventory_list_request(token)
        request = OPERATIONS[:inventory][:list_next]
        soap_request(request) do |xml|
          xml.tag! request, { 'xmlns' => SERVICES[:inventory][:xmlns] } do
            xml.tag! "NextToken", token
          end
        end
      end

      def build_tracking_request(order_id, options)
        request = OPERATIONS[:outbound][:tracking]
        soap_request(request) do |xml|
          xml.tag! request, { 'xmlns' => SERVICES[:outbound][:xmlns] } do
            xml.tag! "MerchantFulfillmentOrderId", order_id
          end
        end
      end

      def add_credentials(xml, request)
        login     = @options[:login]
        timestamp = "#{Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S")}Z"
        signature = self.class.sign(@options[:password], "#{request}#{timestamp}")
      
        xml.tag! 'aws:AWSAccessKeyId', login, AWS_SECURITY_ATTRIBUTES
        xml.tag! 'aws:Signature', signature, AWS_SECURITY_ATTRIBUTES
        xml.tag! 'aws:Timestamp', timestamp, AWS_SECURITY_ATTRIBUTES
      end
        
      def add_items(xml, line_items) 
        Array(line_items).each_with_index do |item, index|
          xml.tag! 'Item' do
            xml.tag! 'MerchantSKU', item[:sku]
            xml.tag! "MerchantFulfillmentOrderItemId", index
            xml.tag! "Quantity",  item[:quantity]
            xml.tag! "GiftMessage", item[:gift_message] unless item[:gift_message].blank?
            xml.tag! "DisplayableComment", item[:comment] unless item[:comment].blank?
          end
        end
      end
    
      def add_address(xml, address)
        xml.tag! 'DestinationAddress' do 
          xml.tag! 'Name', address[:name]
          xml.tag! 'Line1', address[:address1]
          xml.tag! 'Line2', address[:address2] unless address[:address2].blank?
          xml.tag! 'Line3', address[:address3] unless address[:address3].blank?
          xml.tag! 'City', address[:city]
          xml.tag! 'StateOrProvinceCode', address[:state]
          xml.tag! 'CountryCode', address[:country]
          xml.tag! 'PostalCode', address[:zip].upcase
          xml.tag! 'PhoneNumber', address[:phone]  unless address[:phone].blank?
        end
      end
      
      def commit(service, op, body)
        data = ssl_post(SERVICES[service][:url], body, 'Content-Type' => 'application/soap+xml; charset=utf-8')
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
        response[:response_comment]
      end
      
      def parse_response(service, op, xml)
        begin 
          document = REXML::Document.new(xml)
        rescue REXML::ParseException
          return {:success => FAILURE}
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
      
      def parse_fulfillment_response(op, document)
        response = {}
        action   = OPERATIONS[:outbound][op]
        node     = REXML::XPath.first(document, "//ns1:#{action}Response")
        
        response[:response_status]  = SUCCESS
        response[:response_comment] = MESSAGES[op][SUCCESS]
        response
      end

      def parse_inventory_response(document)
        response = {}
        response[:stock_levels] = {}

        document.each_element('//ns1:MerchantSKUSupply') do |node|
          # {MerchantSKU => 'SOME-ID', InStockSupplyQuantity => '101', ...}
          params = node.elements.to_a.each_with_object({}) {|elem, hash| hash[elem.name] = elem.text}

          response[:stock_levels][params['MerchantSKU']] = params['InStockSupplyQuantity'].to_i
        end

        next_token = REXML::XPath.first(document, '//ns1:NextToken')
        response[:next_token] = (next_token ? next_token.text : nil)

        response[:response_status] = SUCCESS
        response
      end
      
      def parse_tracking_response(document)
        response = {}
        response[:tracking_numbers] = {}

        track_node = REXML::XPath.first(document, '//ns1:FulfillmentShipmentPackage/ns1:TrackingNumber')
        if track_node
          id_node = REXML::XPath.first(document, '//ns1:MerchantFulfillmentOrderId')
          response[:tracking_numbers][id_node.text] = [track_node.text]
        end

        response[:response_status] = SUCCESS
        response
      end
      
      def parse_error(http_response)
        response = {}
        response[:http_code] = http_response.code
        response[:http_message] = http_response.message

        document = REXML::Document.new(http_response.body)

        node     = REXML::XPath.first(document, "//env:Fault")

        failed_node = node.find_first_recursive {|sib| sib.name == "Fault" }
        faultcode_node = node.find_first_recursive {|sib| sib.name == "faultcode" }
        faultstring_node = node.find_first_recursive {|sib| sib.name == "faultstring" }
          
        response[:response_status]  = FAILURE
        response[:faultcode]        = faultcode_node ? faultcode_node.text : ""
        response[:faultstring]      = faultstring_node ? faultstring_node.text : ""
        response[:response_comment] = "#{response[:faultcode]} #{response[:faultstring]}"
        response
      rescue REXML::ParseException => e
        response[:http_body]        = http_response.body
        response[:response_status]  = FAILURE
        response[:response_comment] = "#{response[:http_code]}: #{response[:http_message]}"
        response
      end
    end 
  end
end
