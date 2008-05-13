require 'cgi'

module ActiveMerchant
  module Fulfillment
    class ShipwireService < Service
      SERVICE_URLS = { :fulfillment => 'https://www.shipwire.com/exec/FulfillmentServices.php',
                       :inventory   => 'https://www.shipwire.com/exec/InventoryServices.php',
                       :tracking    => 'https://www.shipwire.com/exec/TrackingServices.php'
                     }
                     
      SCHEMA_URLS = { :fulfillment => 'http://www.shipwire.com/exec/download/OrderList.dtd',
                      :inventory   => 'http://www.shipwire.com/exec/download/InventoryUpdate.dtd',
                      :tracking    => 'http://www.shipwire.com/exec/download/TrackingUpdate.dtd'
                    }
                     
      POST_VARS = { :fulfillment => 'OrderListXML',
                    :inventory   => 'InventoryUpdateXML',
                    :tracking    => 'TrackingUpdateXML'
                  }
                  
      WAREHOUSES = { '01' => '01 - Shipwire Chicago',
                     '02' => '02 - Shipwire Los Angeles'
                   }
                   
      # The first is the label, and the last is the code
      def self.shipping_methods
        ActiveSupport::OrderedHash.new(
          [ ['1 Day Service',   '1D'],
            ['2 Day Service',   '2D'],
            ['Ground Service',  'GD'],
            ['Freight Service', 'FT'] ]
        )
      end
                  
      # Pass in the login and password for the shipwire account.
      # Optionally pass in the :test => true to force test mode
      def initialize(options = {})
        requires!(options, :login, :password)
       
        super
      end

      def fulfill(order_id, shipping_address, line_items, options = {})
        commit :fulfillment, build_fulfillment_request(order_id, shipping_address, line_items, options)
      end
      
      def fetch_stock_levels(options = {})
        commit :inventory, build_inventory_request(options)
      end

      def test_mode?
        true
      end

      private
      def build_fulfillment_request(order_id, shipping_address, line_items, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.declare! :DOCTYPE, :OrderList, :SYSTEM, SCHEMA_URLS[:fulfillment]
        xml.tag! 'OrderList' do
          add_credentials(xml)
          xml.tag! 'Referer', 'SHOPIFY'
          add_order(xml, order_id, shipping_address, line_items, options) 
        end
        xml.target!
      end
      
      def build_inventory_request(options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.declare! :DOCTYPE, :InventoryStatus, :SYSTEM, SCHEMA_URLS[:inventory]
        xml.tag! 'InventoryUpdate' do
          add_credentials(xml)
          xml.tag! 'Warehouse', WAREHOUSES[options[:warehouse]]
          xml.tag! 'ProductCode', options[:sku]
        end
      end
      
      def add_credentials(xml)
        xml.tag! 'EmailAddress', @options[:login]
        xml.tag! 'Password', @options[:password]
        xml.tag! 'Server', test? ? 'Test' : 'Production'
      end

      def add_order(xml, order_id, shipping_address, line_items, options)
        xml.tag! 'Order', :id => order_id do
          xml.tag! 'Warehouse', options[:warehouse] || '00'

          add_address(xml, shipping_address)
          xml.tag! 'Shipping', options[:shipping_method] unless options[:shipping_method].blank?

          Array(line_items).each_with_index do |line_item, index|
            add_item(xml, line_item, index)
          end
        end
      end

      def add_address(xml, address)
        xml.tag! 'AddressInfo', :type => 'Ship' do
          xml.tag! 'Name' do
            xml.tag! 'Full', address[:name]
          end
          xml.tag! 'Address1', address[:address1] unless address[:address1].blank?
          xml.tag! 'Address2', address[:address2] unless address[:address2].blank?
          xml.tag! 'City', address[:city] unless address[:city].blank?
          xml.tag! 'State', address[:state] unless address[:state].blank?
          
          unless address[:country].blank?
            country = Country.find(address[:country])
            
            # Special handling for the United Kingdom, as they use the top level domain for the code
            country_code = country.code(:alpha2).to_s == 'GB' ? 'UK' : country.code(:alpha2)
            
            xml.tag! 'Country', "#{country_code} #{country.name}"
          end
          
          xml.tag! 'Zip', address[:zip] unless address[:zip].blank?
          xml.tag! 'Phone', address[:phone] unless address[:phone].blank?
          xml.tag! 'Email', address[:email] unless address[:email].blank?
        end
      end

      def add_item(xml, item, index)
        xml.tag! 'Item', :num => index do
          # Code is limited to 12 character
          xml.tag! 'Code', item[:sku] unless item[:sku].blank?
          xml.tag! 'Quantity', item[:quantity] unless item[:quantity].blank?
          xml.tag! 'Description', item[:description] unless item[:description].blank?
          xml.tag! 'Length', item[:length] unless item[:length].blank?
          xml.tag! 'Width', item[:width] unless item[:width].blank?
          xml.tag! 'Height', item[:height] unless item[:height].blank?
          xml.tag! 'Weight', item[:weight] unless item[:weight].blank?
          xml.tag! 'DeclaredValue', item[:declared_value] unless item[:declared_value].blank?
        end
      end

      def commit(action, request)
        data = ssl_post(SERVICE_URLS[action],
         "#{POST_VARS[action]}=#{CGI.escape(request)}",
         'Content-Type' => 'application/x-www-form-urlencoded'
        )
        
        case action
        when :fulfillment
        
          @response = parse_fulfillment_response(data)
          success = @response[:status] == '0'
          message = success ? "Successfully submitted the order" : message_from(@response[:error_message])
      
          
        when :inventory
          @response = parse_inventory_response(data)
          if test?
            success = @response[:status] == 'Test'
          else
            success = @response[:status] == '0'
          end
          message = success ? "Successfully received the stock levels" : message_from(@response[:error_message])
        end
        
        Response.new(success, message, @response, 
          :test => test?
        )
      end
      
      def parse_fulfillment_response(xml)
        response = {}
        
        document = REXML::Document.new(xml)
        document.root.elements.each do |node|
          response[node.name.underscore.to_sym] = node.text
        end
        response
      end
      
      def parse_inventory_response(xml)
        response = {}
        response[:stock_levels] = {}
        
        document = REXML::Document.new(xml)
        document.root.elements.each do |node|
          if node.name == 'Product'
            response[:stock_levels][node.attributes['code']] = node.attributes['quantity'].to_i
          else
            response[node.name.underscore.to_sym] = node.text
          end
        end
        response
      end
      
      def message_from(string)
        return if string.blank?
        string.gsub("\n", '').squeeze(" ")
      end
    end
  end
end


