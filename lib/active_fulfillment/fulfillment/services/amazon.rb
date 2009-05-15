module ActiveMerchant
  module Fulfillment
    class AmazonService < Service
      URL = 'https://fba.amazonaws.com/FulfillmentService'
    
      SUCCESS, FAILURE, ERROR = 'Accepted', 'Failure', 'Error'    
      MESSAGES = {
        :success => 'Successfully submitted the order',
        :failure => 'Failed to submit the order',
        :error   => 'An error occurred while submitting the order'
      }
      
      XMLNS = "http://fulfillment.amazonaws.com/doc/FulfillmentService/2006-12-12"
      
      INVALID_LOGIN = "aws:Client.InvalidAccessKeyId"
      
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
        super
        
        @url = URL
      end

      def fulfill(order_id, shipping_address, line_items, options = {})   
        requires!(options, :order_date, :comment, :shipping_method)
        commit build_fulfillment_request(order_id, shipping_address, line_items, options)
      end
      
      def fetch_current_orders
        commit build_get_current_fulfillment_orders_request
      end
      
      def valid_credentials?
        response = fulfill('', {}, [],
                     :order_date => Time.now,
                     :comment => '',
                     :shipping_method => ''
                   )
        response.params["faultcode"] != INVALID_LOGIN
      end
   
      def test_mode?
        false
      end

      private
      
      def build_get_current_fulfillment_orders_request
          xml = Builder::XmlMarkup.new
          
          xml.tag! 'GetCurrentFulfillmentOrders', { 'xmlns' => XMLNS } do
            xml.tag! 'Request' do
              add_credentials(xml)
              
              xml.tag! "MaxResultsRequested", 5
              xml.tag! "QueryStartDateTime", Time.now.yesterday.strftime("%Y-%m-%d %H:%M:%S")
            end
          end
          xml.target!
       end
      
       def build_fulfillment_request(order_id, shipping_address, line_items, options)
          xml = Builder::XmlMarkup.new
       
          xml.tag! 'CreateFulfillmentOrder', { 'xmlns' => XMLNS } do
            xml.tag! 'Request' do
               add_credentials(xml)
              
               xml.tag! "MerchantFulfillmentOrderId", order_id
               xml.tag! "DisplayableOrderId", order_id
               xml.tag! "DisplayableOrderDate", options[:order_date].strftime("%Y-%m-%dT%H:%M:%SZ")
               xml.tag! "DisplayableOrderComment", options[:comment]
               xml.tag! "DeliverySLA", options[:shipping_method]
               
               add_address(xml, shipping_address)
               add_items(xml, line_items)
            end
          end
          xml.target!
       end
      
      def add_credentials(xml)
        xml.tag! 'Credentials' do 
          xml.tag! 'Email', @options[:login]
          xml.tag! 'Password', @options[:password]
        end
      end
        
      def add_items(xml, line_items) 
        Array(line_items).each_with_index do |item, index|
          xml.tag! 'Items' do
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
          xml.tag! 'StateOrRegion', address[:state]
          xml.tag! 'CountryCode', address[:country]
          xml.tag! 'PostalCode', address[:zip]
          xml.tag! 'PhoneNumber', address[:phone]  unless address[:phone].blank?
        end
      end
      
      def build_request(body)
        xml = Builder::XmlMarkup.new
     
        xml.instruct!
        xml.tag! 'env:Envelope', { 'xmlns:env' => 'http://schemas.xmlsoap.org/soap/envelope/' } do
          xml.tag! 'env:Body' do
            xml << body
          end
        end
        xml.target!
      end
      
      def commit(body)
        data = ssl_post(@url, build_request(body), 'Content-Type' => 'application/soap+xml; charset=utf-8')
        @response = parse(data)
                
        Response.new(success?(@response), message_from(@response), @response, 
          :test => false
        )
      end
      
      def success?(response)
        response[:response_status] == SUCCESS
      end
      
      def message_from(response)
        success?(response) ? MESSAGES[:success] : response[:response_comment] || response[:faultstring]
      end
      
      def parse(xml)
        response = {}
        
        begin 
          document = REXML::Document.new(xml)
          
          node = REXML::XPath.first(document, '//ns1:Response') || REXML::XPath.first(document, '//env:Fault')
          if node
            parse_elements(response, node)
          else
            response[:response_status] = FAILURE
            response[:response_comment] = MESSAGES[:failure]
          end
        rescue REXML::ParseException
          response[:response_status] = ERROR
          response[:response_comment] = MESSAGES[:error]
        end
        
        response
      end
      
      def parse_elements(response, node)
        node.elements.each do |e|
          response[e.name.underscore.to_sym] = e.text.to_s.gsub("\n", " ").strip
        end
      end
    end
  end
end


