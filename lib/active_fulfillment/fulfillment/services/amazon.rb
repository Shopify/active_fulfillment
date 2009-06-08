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
      
      OPERATIONS = {
        :status => 'GetServiceStatus',
        :create => 'CreateFulfillmentOrder',
        :list   => 'ListAllFulfillmentOrders'
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

      def status
        commit :status, build_status_request
      end
      
      # def status
      #   login = @options[:login]
      #   timestamp = "#{Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S")}Z"
      #   signature = self.class.sign(@options[:password], "GetServiceStatus#{timestamp}")
      #   
      #   url = "#{OUTBOUND_URL}?Action=GetServiceStatus&Version=#{VERSION}&AWSAccessKeyId=#{login}&Timestamp=#{timestamp}&Signature=#{signature}"
      #   
      #   response = ssl_get(url)
      # end

      
      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def fulfill(order_id, shipping_address, line_items, options = {})   
        requires!(options, :order_date, :comment, :shipping_method)
        commit :create, build_fulfillment_request(order_id, shipping_address, line_items, options)
      end
      
      def fetch_current_orders
        commit :list, build_get_current_fulfillment_orders_request
      end
      
      def valid_credentials?
        status.success?
      end
   
      def test_mode?
        false
      end

      private
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
      
      # STATUS request
      def build_status_request
        request = OPERATIONS[:status]
        soap_request(request) do |xml|
          xml.tag! request, { 'xmlns' => OUTBOUND_XMLNS }
        end
      end
      
      # LIST ORDERS request
      def build_get_current_fulfillment_orders_request
        request = OPERATIONS[:list]
        soap_request(request) do |xml|
          xml.tag! request, { 'xmlns' => OUTBOUND_XMLNS } do
            xml.tag! "NumberOfResultsRequested", 5
            xml.tag! "QueryStartDateTime", Time.now.utc.yesterday.strftime("%Y-%m-%dT%H:%M:%SZ")
          end
        end
      end

      # POST FULFILLMENT request
      def build_fulfillment_request(order_id, shipping_address, line_items, options)
        request = OPERATIONS[:create]
        soap_request(request) do |xml|
          xml.tag! request, { 'xmlns' => OUTBOUND_XMLNS } do
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
          xml.tag! 'PostalCode', address[:zip]
          xml.tag! 'PhoneNumber', address[:phone]  unless address[:phone].blank?
        end
      end
      
      def commit(op, body)
        data = ssl_post(OUTBOUND_URL, body, 'Content-Type' => 'application/soap+xml; charset=utf-8')
        response = parse(op, data)   
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
      
      def parse(op, xml)
        response = {}
        action   = OPERATIONS[op]                
        document = REXML::Document.new(xml)
        node     = REXML::XPath.first(document, "//ns1:#{action}Response")
        
        response[:response_status]  = SUCCESS
        response[:response_comment] = MESSAGES[op][SUCCESS]
        response
      end
      
      # extra the error message
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


     
# valid CREATE response
# ---------------------
# <?xml version="1.0"?>
# <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
#   <env:Body>
#     <ns1:CreateFulfillmentOrderResponse xmlns:ns1="http://fba-outbound.amazonaws.com/doc/2007-08-02/">
#       <ns1:ResponseMetadata>
#         <ns1:RequestId>ccd0116d-a476-48ac-810e-778eebe5e5e2</ns1:RequestId>
#       </ns1:ResponseMetadata>
#     </ns1:CreateFulfillmentOrderResponse>
#   </env:Body>
# </env:Envelope>
#
# invalid CREATE response
# -----------------------
# <?xml version="1.0"?>
# <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:aws="http://webservices.amazon.com/AWSFault/2005-15-09">
#   <env:Body>
#     <env:Fault>
#       <faultcode>aws:Client.MissingParameter</faultcode>
#       <faultstring>The request must contain the parameter Item.</faultstring>
#       <detail>
#         <aws:RequestId xmlns:aws="http://webservices.amazon.com/AWSFault/2005-15-09">edc852d3-937f-40f5-9d72-97b7da897b38</aws:RequestId>
#       </detail>
#     </env:Fault>
#   </env:Body>
# </env:Envelope>

# valid STATUS response
# ---------------------
# <?xml version="1.0"?>
# <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
#   <env:Body>
#     <ns1:GetServiceStatusResponse xmlns:ns1="http://fba-outbound.amazonaws.com/doc/2007-08-02/">
#       <ns1:GetServiceStatusResult>
#         <ns1:Status>2009-06-05T18:36:19Z service available [Version: 2007-08-02]</ns1:Status>
#       </ns1:GetServiceStatusResult>
#       <ns1:ResponseMetadata>
#         <ns1:RequestId>1e04fabc-fbaa-4ae5-836a-f0c60f1d301a</ns1:RequestId>
#       </ns1:ResponseMetadata>
#     </ns1:GetServiceStatusResponse>
#   </env:Body>
# </env:Envelope>
#
# invalid STATUS response
# -----------------------
# <?xml version="1.0"?>
# <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:aws="http://webservices.amazon.com/AWSFault/2005-15-09">
#   <env:Body>
#     <env:Fault>
#       <faultcode>aws:Client.InvalidClientTokenId</faultcode>
#       <faultstring>The AWS Access Key Id you provided does not exist in our records.</faultstring>
#       <detail>
#         <aws:RequestId xmlns:aws="http://webservices.amazon.com/AWSFault/2005-15-09">51de28ce-c380-46c4-bf95-62bbf8cc4682</aws:RequestId>
#       </detail>
#     </env:Fault>
#   </env:Body>
# </env:Envelope>  

# valid LIST response
# -------------------
# <?xml version="1.0"?>
# <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
#   <env:Body>
#     <ns1:ListAllFulfillmentOrdersResponse xmlns:ns1="http://fba-outbound.amazonaws.com/doc/2007-08-02/">
#       <ns1:ListAllFulfillmentOrdersResult>
#         <ns1:NextToken>H4sIAAAAAAAAALMpVMi0VTJTUsizVTJVUsi1VUpLzClOVVJItVUyMjCw1DUw0zUwDTG0sDKxtDK21LM0NdY1MLcyMFBSKEZSYRJiaAJRAZW1s0mzC3L19Q9z9LHRTwPxnP39gkN9XYPAXP1COwCEc53ZegAAAA==</ns1:NextToken>
#         <ns1:HasNext>false</ns1:HasNext>
#         <ns1:FulfillmentOrder>
#           <ns1:MerchantFulfillmentOrderId>c7f7921c29e966f2f50272a532deca9c</ns1:MerchantFulfillmentOrderId>
#           <ns1:DisplayableOrderId>c7f7921c29e966f2f50272a532deca9c</ns1:DisplayableOrderId>
#           <ns1:DisplayableOrderDateTime>2009-06-04T18:30:19Z</ns1:DisplayableOrderDateTime>
#           <ns1:DisplayableOrderComment>Delayed due to tornados</ns1:DisplayableOrderComment>
#           <ns1:ShippingSpeedCategory>Standard</ns1:ShippingSpeedCategory>
#           <ns1:DestinationAddress>
#             <ns1:Name>Johnny Chase</ns1:Name>
#             <ns1:Line1>100 Information Super Highway</ns1:Line1>
#             <ns1:Line2>Suite 66</ns1:Line2>
#             <ns1:City>Beverly Hills</ns1:City>
#             <ns1:StateOrProvinceCode>CA</ns1:StateOrProvinceCode>
#             <ns1:CountryCode>US</ns1:CountryCode>
#             <ns1:PostalCode>90210</ns1:PostalCode>
#           </ns1:DestinationAddress>
#           <ns1:FulfillmentPolicy>FillOrKill</ns1:FulfillmentPolicy>
#           <ns1:FulfillmentMethod>Consumer</ns1:FulfillmentMethod>
#           <ns1:ReceivedDateTime>2009-06-05T18:30:19Z</ns1:ReceivedDateTime>
#           <ns1:FulfillmentOrderStatus>Invalid</ns1:FulfillmentOrderStatus>
#           <ns1:StatusUpdatedDateTime>2009-06-05T18:30:46Z</ns1:StatusUpdatedDateTime>
#         </ns1:FulfillmentOrder>
#         <ns1:FulfillmentOrder>
#           <ns1:MerchantFulfillmentOrderId>168b078302d18db7f39415431a860e6b</ns1:MerchantFulfillmentOrderId>
#           <ns1:DisplayableOrderId>168b078302d18db7f39415431a860e6b</ns1:DisplayableOrderId>
#           <ns1:DisplayableOrderDateTime>2009-06-04T18:40:08Z</ns1:DisplayableOrderDateTime>
#           <ns1:DisplayableOrderComment>Delayed due to tornados</ns1:DisplayableOrderComment>
#           <ns1:ShippingSpeedCategory>Standard</ns1:ShippingSpeedCategory>
#           <ns1:DestinationAddress>
#             <ns1:Name>Johnny Chase</ns1:Name>
#             <ns1:Line1>100 Information Super Highway</ns1:Line1>
#             <ns1:Line2>Suite 66</ns1:Line2>
#             <ns1:City>Beverly Hills</ns1:City>
#             <ns1:StateOrProvinceCode>CA</ns1:StateOrProvinceCode>
#             <ns1:CountryCode>US</ns1:CountryCode>
#             <ns1:PostalCode>90210</ns1:PostalCode>
#           </ns1:DestinationAddress>
#           <ns1:FulfillmentPolicy>FillOrKill</ns1:FulfillmentPolicy>
#           <ns1:FulfillmentMethod>Consumer</ns1:FulfillmentMethod>
#           <ns1:ReceivedDateTime>2009-06-05T18:40:08Z</ns1:ReceivedDateTime>
#           <ns1:FulfillmentOrderStatus>Invalid</ns1:FulfillmentOrderStatus>
#           <ns1:StatusUpdatedDateTime>2009-06-05T18:40:16Z</ns1:StatusUpdatedDateTime>
#         </ns1:FulfillmentOrder>
#         <ns1:FulfillmentOrder>
#           <ns1:MerchantFulfillmentOrderId>d9ade2d2ceab0b57457949169cd5ad7e</ns1:MerchantFulfillmentOrderId>
#           <ns1:DisplayableOrderId>d9ade2d2ceab0b57457949169cd5ad7e</ns1:DisplayableOrderId>
#           <ns1:DisplayableOrderDateTime>2009-06-04T18:40:35Z</ns1:DisplayableOrderDateTime>
#           <ns1:DisplayableOrderComment>Delayed due to tornados</ns1:DisplayableOrderComment>
#           <ns1:ShippingSpeedCategory>Standard</ns1:ShippingSpeedCategory>
#           <ns1:DestinationAddress>
#             <ns1:Name>Johnny Chase</ns1:Name>
#             <ns1:Line1>100 Information Super Highway</ns1:Line1>
#             <ns1:Line2>Suite 66</ns1:Line2>
#             <ns1:City>Beverly Hills</ns1:City>
#             <ns1:StateOrProvinceCode>CA</ns1:StateOrProvinceCode>
#             <ns1:CountryCode>US</ns1:CountryCode>
#             <ns1:PostalCode>90210</ns1:PostalCode>
#           </ns1:DestinationAddress>
#           <ns1:FulfillmentPolicy>FillOrKill</ns1:FulfillmentPolicy>
#           <ns1:FulfillmentMethod>Consumer</ns1:FulfillmentMethod>
#           <ns1:ReceivedDateTime>2009-06-05T18:40:36Z</ns1:ReceivedDateTime>
#           <ns1:FulfillmentOrderStatus>Invalid</ns1:FulfillmentOrderStatus>
#           <ns1:StatusUpdatedDateTime>2009-06-05T18:40:41Z</ns1:StatusUpdatedDateTime>
#         </ns1:FulfillmentOrder>
#         <ns1:FulfillmentOrder>
#           <ns1:MerchantFulfillmentOrderId>9fc3f2e379fe36d56ffa00e2e052ba94</ns1:MerchantFulfillmentOrderId>
#           <ns1:DisplayableOrderId>9fc3f2e379fe36d56ffa00e2e052ba94</ns1:DisplayableOrderId>
#           <ns1:DisplayableOrderDateTime>2009-06-04T18:40:52Z</ns1:DisplayableOrderDateTime>
#           <ns1:DisplayableOrderComment>Delayed due to tornados</ns1:DisplayableOrderComment>
#           <ns1:ShippingSpeedCategory>Standard</ns1:ShippingSpeedCategory>
#           <ns1:DestinationAddress>
#             <ns1:Name>Johnny Chase</ns1:Name>
#             <ns1:Line1>100 Information Super Highway</ns1:Line1>
#             <ns1:Line2>Suite 66</ns1:Line2>
#             <ns1:City>Beverly Hills</ns1:City>
#             <ns1:StateOrProvinceCode>CA</ns1:StateOrProvinceCode>
#             <ns1:CountryCode>US</ns1:CountryCode>
#             <ns1:PostalCode>90210</ns1:PostalCode>
#           </ns1:DestinationAddress>
#           <ns1:FulfillmentPolicy>FillOrKill</ns1:FulfillmentPolicy>
#           <ns1:FulfillmentMethod>Consumer</ns1:FulfillmentMethod>
#           <ns1:ReceivedDateTime>2009-06-05T18:40:52Z</ns1:ReceivedDateTime>
#           <ns1:FulfillmentOrderStatus>Invalid</ns1:FulfillmentOrderStatus>
#           <ns1:StatusUpdatedDateTime>2009-06-05T18:41:16Z</ns1:StatusUpdatedDateTime>
#         </ns1:FulfillmentOrder>
#         <ns1:FulfillmentOrder>
#           <ns1:MerchantFulfillmentOrderId>bd97c45f78d83b654c1948ad6a476ade</ns1:MerchantFulfillmentOrderId>
#           <ns1:DisplayableOrderId>bd97c45f78d83b654c1948ad6a476ade</ns1:DisplayableOrderId>
#           <ns1:DisplayableOrderDateTime>2009-06-04T18:46:48Z</ns1:DisplayableOrderDateTime>
#           <ns1:DisplayableOrderComment>Delayed due to tornados</ns1:DisplayableOrderComment>
#           <ns1:ShippingSpeedCategory>Standard</ns1:ShippingSpeedCategory>
#           <ns1:DestinationAddress>
#             <ns1:Name>Johnny Chase</ns1:Name>
#             <ns1:Line1>100 Information Super Highway</ns1:Line1>
#             <ns1:Line2>Suite 66</ns1:Line2>
#             <ns1:City>Beverly Hills</ns1:City>
#             <ns1:StateOrProvinceCode>CA</ns1:StateOrProvinceCode>
#             <ns1:CountryCode>US</ns1:CountryCode>
#             <ns1:PostalCode>90210</ns1:PostalCode>
#           </ns1:DestinationAddress>
#           <ns1:FulfillmentPolicy>FillOrKill</ns1:FulfillmentPolicy>
#           <ns1:FulfillmentMethod>Consumer</ns1:FulfillmentMethod>
#           <ns1:ReceivedDateTime>2009-06-05T18:46:48Z</ns1:ReceivedDateTime>
#           <ns1:FulfillmentOrderStatus>Invalid</ns1:FulfillmentOrderStatus>
#           <ns1:StatusUpdatedDateTime>2009-06-05T18:47:22Z</ns1:StatusUpdatedDateTime>
#         </ns1:FulfillmentOrder>
#       </ns1:ListAllFulfillmentOrdersResult>
#       <ns1:ResponseMetadata>
#         <ns1:RequestId>1c9038ff-da88-4152-9fb0-8ab8fabccea4</ns1:RequestId>
#       </ns1:ResponseMetadata>
#     </ns1:ListAllFulfillmentOrdersResponse>
#   </env:Body>
# </env:Envelope>

