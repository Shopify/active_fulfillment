module ActiveMerchant
  module Fulfillment
    class WebgistixService < Service
      TEST_URL = 'https://www.webgistix.com/XML/shippingTest.asp'
      LIVE_URL = 'https://www.webgistix.com/XML/API.asp'
      
      SUCCESS, FAILURE = 'True', 'False'
      SUCCESS_MESSAGE = 'Successfully submitted the order'
      FAILURE_MESSAGE = 'Failed to submit the order'
      
      # The first is the label, and the last is the code
      def self.shipping_methods
        [ 
          ["UPS Ground Shipping", "Ground"],
          ["UPS Standard Shipping (Canada Only)", "Standard"],
          ["UPS 3-Business Day", "3-Day Select"],
          ["UPS 2-Business Day", "2nd Day Air"],
          ["UPS 2-Business Day AM", "2nd Day Air AM"],
          ["UPS Next Day", "Next Day Air"],
          ["UPS Next Day Saver", "Next Day Air Saver"],
          ["UPS Next Day Early AM", "Next Day Air Early AM"],
          ["UPS Worldwide Express (Next Day)", "Worldwide Express"],
          ["UPS Worldwide Expedited (2nd Day)", "Worldwide Expedited"],
          ["UPS Worldwide Express Saver", "Worldwide Express Saver"],
          ["FedEx Priority Overnight", "FedEx Priority Overnight"],
          ["FedEx Standard Overnight", "FedEx Standard Overnight"],
          ["FedEx First Overnight", "FedEx First Overnight"],
          ["FedEx 2nd Day", "FedEx 2nd Day"],
          ["FedEx Express Saver", "FedEx Express Saver"],
          ["FedEx International Priority", "FedEx International Priority"],
          ["FedEx International Economy", "FedEx International Economy"],
          ["FedEx International First", "FedEx International First"],
          ["FedEx Ground", "FedEx Ground"],
          ["USPS Priority Mail & Global Priority Mail", "Priority"],
          ["USPS First Class Mail", "First Class"],
          ["USPS Express Mail & Global Express Mail", "Express"],
          ["USPS Parcel Post", "Parcel"],
          ["USPS Air Letter Post", "Air Letter Post"],
          ["USPS Media Mail", "Media Mail"],
          ["USPS Economy Parcel Post", "Economy Parcel"],
          ["USPS Economy Air Letter Post", "Economy Letter"],
          ["DHL Express", "DHL Express"],
          ["DHL Next Afternoon", "DHL Next Afternoon"],
          ["DHL Second Day Service", "DHL Second Day Service"],
          ["DHL Ground", "DHL Ground"],
          ["DHL International Express", "DHL International Express"]
        ].inject(ActiveSupport::OrderedHash.new){|h, (k,v)| h[k] = v; h}
      end
      
      # Pass in the login and password for the shipwire account.
      # Optionally pass in the :test => true to force test mode
      def initialize(options = {})
        requires!(options, :login, :password)
        super
        @url = test? ? TEST_URL : LIVE_URL
      end

      def fulfill(order_id, shipping_address, line_items, options = {})  
        requires!(options, :shipping_method) 
        commit build_fulfillment_request(order_id, shipping_address, line_items, options)
      end
   
      def test_mode?
        true
      end

      private
      #<?xml version="1.0"?> 
      # <OrderXML> 
      #   <Password>Webgistix</Password> 
      #   <CustomerID>3</CustomerID> 
      #   <Order> 
      #     <ReferenceNumber></ReferenceNumber> 
      #     <Company>Test Company</Company> 
      #     <Name>Joe Smith</Name> 
      #     <Address1>123 Main St.</Address1> 
      #     <Address2></Address2> 
      #     <Address3></Address3> 
      #     <City>Olean</City> 
      #     <State>NY</State> 
      #     <ZipCode>14760</ZipCode> 
      #     <Country>United States</Country> 
      #     <Email>info@webgistix.com</Email> 
      #     <Phone>1-123-456-7890</Phone> 
      #     <ShippingInstructions>Ground</ShippingInstructions> 
      #     <OrderComments>Test Order</OrderComments> 
      #     <Approve>0</Approve> 
      #     <Item> 
      #      <ItemID>testitem</ItemID> 
      #      <ItemQty>2</ItemQty> 
      #     </Item> 
      #   </Order> 
      # </OrderXML>
      def build_fulfillment_request(order_id, shipping_address, line_items, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! 'OrderXML' do
          add_credentials(xml)
          add_order(xml, order_id, shipping_address, line_items, options) 
        end
        xml.target!
      end
      
      def add_credentials(xml)
        xml.tag! 'CustomerID', @options[:login]
        xml.tag! 'Password', @options[:password]
      end

      def add_order(xml, order_id, shipping_address, line_items, options)
        xml.tag! 'Order' do
          xml.tag! 'ReferenceNumber', order_id
          xml.tag! 'ShippingInstructions', options[:shipping_method]
          xml.tag! 'Approve', 1
          xml.tag! 'OrderComments', options[:comment] unless options[:comment].blank?
    
          add_address(xml, shipping_address, options)

          Array(line_items).each_with_index do |line_item, index|
            add_item(xml, line_item, index)
          end
        end
      end
      
      def add_address(xml, address, options)
        xml.tag! 'Name', address[:name]
        xml.tag! 'Address1', address[:address1]
        xml.tag! 'Address2', address[:address2] unless address[:address2].blank?
        xml.tag! 'Address3', address[:address3] unless address[:address3].blank?
        xml.tag! 'City', address[:city]
        xml.tag! 'State', address[:state]
        xml.tag! 'ZipCode', address[:zip]
        xml.tag! 'Company', address[:company]
          
        unless address[:country].blank?
          country = Country.find(address[:country])
          xml.tag! 'Country', country.name
        end
        
        xml.tag! 'Phone', address[:phone]
        xml.tag! 'Email', options[:email] unless options[:email].blank?
      end

      def add_item(xml, item, index)
        xml.tag! 'Item' do
          xml.tag! 'ItemID', item[:sku] unless item[:sku].blank?
          xml.tag! 'ItemQty', item[:quantity] unless item[:quantity].blank?
        end
      end

      def commit(request)
        @response = parse(ssl_post(@url, request,
                            'EndPointURL'  => @url,
                            'Content-Type' => 'text/xml; charset="utf-8"')
                         )
        
        Response.new(success?(@response), message_from(@response), @response, 
          :test => test?
        )
      end
      
      def success?(response)
        response[:success] == SUCCESS
      end
      
      def message_from(response)
        return SUCCESS_MESSAGE if success?(response)

        if response[:error_0] == 'Access Denied'
          response[:error_0]
        else
          FAILURE_MESSAGE
        end
      end
      
      def parse(xml)
        response = {}
        
        begin 
          document = REXML::Document.new("<response>#{xml}</response>")
        rescue REXML::ParseException
          response[:success] = FAILURE
          return response
        end
        # Fetch the errors
        document.root.elements.to_a("Error").each_with_index do |e, i|
          response["error_#{i}".to_sym] = e.text
        end
        
        # Check if completed
        if completed = REXML::XPath.first(document, '//Completed')
          completed.elements.each do |e|
            response[e.name.underscore.to_sym] = e.text
          end
        else
          response[:success] = FAILURE
        end
        
        response
      end
    end
  end
end


