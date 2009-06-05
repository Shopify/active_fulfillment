require 'base64'
require 'openssl'

module ActiveMerchant
  module Fulfillment
    class AmazonService < Service
      OUTBOUND_URL   = "https://fba-outbound.amazonaws.com"
      OUTBOUND_XMLNS = 'http://fba-outbound.amazonaws.com/doc/2007-08-02/'
      VERSION        = "2007-08-02"
    
      SUCCESS, FAILURE, ERROR = 'Accepted', 'Failure', 'Error'    
      MESSAGES = {
        :success => 'Successfully submitted the order',
        :failure => 'Failed to submit the order',
        :error   => 'An error occurred while submitting the order'
      }
      
      INVALID_LOGIN  = "aws:Client.InvalidAccessKeyId"    
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

      # def status
      #         login = @options[:login]
      #         timestamp = "#{Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S")}Z"
      #         signature = self.class.sign(@options[:password], "GetServiceStatus#{timestamp}")
      #         
      #         url = "#{OUTBOUND_URL}?Action=GetServiceStatus&Version=#{VERSION}&AWSAccessKeyId=#{login}&Timestamp=#{timestamp}&Signature=#{signature}"
      #         
      #         response = ssl_get(url)
      #       end
      
      def status
        commit build_status_request
      end
      
      def initialize(options = {})
        requires!(options, :login, :password)
        super
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
      
      
      

    #     <env:Body>
    #         <CreateFulfillmentOrder 
    #             xmlns="http://fba-outbound.amazonaws.com/doc/2007-08-02/"> 
    #             <MerchantFulfillmentOrderId>create-2items-20080124165703154</ 
    # MerchantFulfillmentOrderId> 
    #             <DisplayableOrderId>create-2items-20080124165703154</ 
    # DisplayableOrderId> 
    #             <DisplayableOrderDateTime>2008-01-24T08:00:00Z</ 
    # DisplayableOrderDateTime> 
    #             <DisplayableOrderComment>Thank you for your order!</ 
    # DisplayableOrderComment> 
    #             <ShippingSpeedCategory>Standard</ShippingSpeedCategory> 
    #             <DestinationAddress> 
    #                 <Name>Joey Jo Jo Shabadoo Jr</Name> 
    #                 <Line1>605 5th Ave N</Line1> 
    #                 <Line2>C/O Amazon.com</Line2> 
    #                 <City>Seattle</City> 
    #                 <StateOrProvinceCode>WA</StateOrProvinceCode> 
    #                 <CountryCode>US</CountryCode> 
    #                 <PostalCode>98104</PostalCode> 
    #                 <PhoneNumber>206-266-1000</PhoneNumber> 
    #             </DestinationAddress> 
    #             <Item> 
    #                 <MerchantSKU>Digital_Camera_Extraordinaire</MerchantSKU> 
    #            
    #  <MerchantFulfillmentOrderItemId>create-2items-20080124165703154-1</ 
    # MerchantFulfillmentOrderItemId> 
    #                 <Quantity>1</Quantity> 
    #                 <GiftMessage>Testing gift message #1</GiftMessage> 
    #                 <DisplayableComment>Testing item comment 
    #                     #1</DisplayableComment> 
    #             </Item> 
    #             <Item> 
    #                 <MerchantSKU>Digital_Camera_Extraordinaire</MerchantSKU> 
    #            
    #  <MerchantFulfillmentOrderItemId>create-2items-20080124165703154-2</ 
    # MerchantFulfillmentOrderItemId> 
    #                 <Quantity>2</Quantity> 
    #                 <GiftMessage>Testing gift message #2</GiftMessage> 
    #                 <DisplayableComment>Testing item comment 
    #                     #2</DisplayableComment> 
    #             </Item> 
    #         </CreateFulfillmentOrder> 
    #     </env:Body> 
    # </env:Envelope>
      
      # generic request format 
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
      
      # <?xml version="1.0" encoding="UTF-8"?> 
      # <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" 
      #     xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
      #     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"> 
      #     <env:Header> 
      #         <aws:AWSAccessKeyId env:actor="http://schemas.xmlsoap.org/soap/ 
      # actor/next" 
      #             env:mustUnderstand="0" xmlns:aws="http:// 
      # security.amazonaws.com/doc/2007-01-01/" 
      #             >0QY05JR56ZA8E56XPG82</aws:AWSAccessKeyId> 
      #         <aws:Signature env:actor="http://schemas.xmlsoap.org/soap/actor/ 
      # next" 
      #             env:mustUnderstand="0" xmlns:aws="http:// 
      # security.amazonaws.com/doc/2007-01-01/" 
      #             >zs1XVLJIZMA583oInQdWghEdPBg=</aws:Signature> 
      #         <aws:Timestamp env:actor="http://schemas.xmlsoap.org/soap/actor/ 
      # next" 
      #             env:mustUnderstand="0" xmlns:aws="http:// 
      # security.amazonaws.com/doc/2007-01-01/" 
      #             >2008-01-25T00:56:58Z</aws:Timestamp> 
      #     </env:Header> 
      #     <env:Body> 
      #         <GetServiceStatus xmlns="http://fba-outbound.amazonaws.com/ 
      # doc/2007-08-02/"/> 
      #     </env:Body> 
      # </env:Envelope>      
      
      
      def build_status_request
        request = 'GetServiceStatus'
        soap_request(request) do |xml|
          xml.tag! request, { 'xmlns' => OUTBOUND_XMLNS }
        end
      end
      
      def build_get_current_fulfillment_orders_request
        request = "GetCurrentFulfillmentOrders"
        xml = Builder::XmlMarkup.new
          
        xml.tag! request, { 'xmlns' => OUTBOUND_XMLNS } do
          xml.tag! 'Request' do
            xml.tag! "MaxResultsRequested", 5
            xml.tag! "QueryStartDateTime", Time.now.yesterday.strftime("%Y-%m-%d %H:%M:%S")
          end
        end
        xml.target!
      end

      def build_fulfillment_request(order_id, shipping_address, line_items, options)
        request = 'CreateFulfillmentOrder'
        soap_request(request) do |xml|
          xml.tag! 'Request' do
             xml.tag! "MerchantFulfillmentOrderId", order_id
             xml.tag! "DisplayableOrderId", order_id
             xml.tag! "DisplayableOrderDate", options[:order_date].strftime("%Y-%m-%dT%H:%M:%SZ")
             xml.tag! "DisplayableOrderComment", options[:comment]
             xml.tag! "DeliverySLA", options[:shipping_method]
   
             add_address(xml, shipping_address)
             add_items(xml, line_items)
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
        request = ""
        xml = Builder::XmlMarkup.new
     
        xml.instruct!
        xml.tag! 'env:Envelope', { 'xmlns:env' => 'http://schemas.xmlsoap.org/soap/envelope/' } do
          xml.tag! 'env:Header' do
            add_credentials(xml, request)
          end
          xml.tag! 'env:Body' do
            xml << body
          end
        end
        xml.target!
      end
      
      def commit(body)         
        data = ssl_post(OUTBOUND_URL, body, 'Content-Type' => 'application/soap+xml; charset=utf-8')

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
        
        document = REXML::Document.new(xml)
        
        node = REXML::XPath.first(document, '//ns1:Response') || REXML::XPath.first(document, '//env:Fault')
        if node
          parse_elements(response, node)
        else
          response[:response_status] = FAILURE
          response[:response_comment] = MESSAGES[:failure]
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


