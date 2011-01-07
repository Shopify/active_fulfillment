require 'cgi'

module ActiveMerchant
  module Fulfillment
    class ShipwireService < Service
      SERVICE_URLS = { :fulfillment => 'https://api.shipwire.com/exec/FulfillmentServices.php',
                       :inventory   => 'https://api.shipwire.com/exec/InventoryServices.php',
                       :tracking    => 'https://api.shipwire.com/exec/TrackingServices.php'
                     }
                     
      SCHEMA_URLS = { :fulfillment => 'http://www.shipwire.com/exec/download/OrderList.dtd',
                      :inventory   => 'http://www.shipwire.com/exec/download/InventoryUpdate.dtd',
                      :tracking    => 'http://www.shipwire.com/exec/download/TrackingUpdate.dtd'
                    }
                     
      POST_VARS = { :fulfillment => 'OrderListXML',
                    :inventory   => 'InventoryUpdateXML',
                    :tracking    => 'TrackingUpdateXML'
                  }
  
      WAREHOUSES = { 'CHI' => 'Chicago',
                     'LAX' => 'Los Angeles',
                     'REN' => 'Reno',
                     'VAN' => 'Vancouver',
                     'TOR' => 'Toronto',
                     'UK'  => 'United Kingdom'
                   }
                   
      INVALID_LOGIN = /Error with EmailAddress, valid email is required/
                   
      # The first is the label, and the last is the code
      def self.shipping_methods
        [ ['1 Day Service',   '1D'],
          ['2 Day Service',   '2D'],
          ['Ground Service',  'GD'],
          ['Freight Service', 'FT'],
          ['International', 'INTL']
        ].inject(ActiveSupport::OrderedHash.new){|h, (k,v)| h[k] = v; h}
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
      
      def fetch_tracking_numbers(order_ids)
        commit :tracking, build_tracking_request(order_ids)
      end
      
      def valid_credentials?
        response = fetch_tracking_numbers([])
        response.message !~ INVALID_LOGIN
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
          xml.tag! 'Referer', 'Active Fulfillment'
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
      
      def build_tracking_request(order_ids)
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.declare! :DOCTYPE, :InventoryStatus, :SYSTEM, SCHEMA_URLS[:inventory]
        xml.tag! 'TrackingUpdate' do
          add_credentials(xml)
          xml.tag! 'Server', test? ? 'Test' : 'Production'
          order_ids.each do |o_id|
            xml.tag! 'OrderNo', o_id
          end
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

          add_address(xml, shipping_address, options)
          xml.tag! 'Shipping', options[:shipping_method] unless options[:shipping_method].blank?

          Array(line_items).each_with_index do |line_item, index|
            add_item(xml, line_item, index)
          end
        end
      end

      def add_address(xml, address, options)
        xml.tag! 'AddressInfo', :type => 'Ship' do
          xml.tag! 'Name' do
            xml.tag! 'Full', address[:name]
          end
          
          if address[:company].blank?
            xml.tag! 'Address1', address[:address1]
            xml.tag! 'Address2', address[:address2]
          else
            xml.tag! 'Address1', address[:company]
            xml.tag! 'Address2', address[:address1]
            xml.tag! 'Address3', address[:address2]
          end
          
          xml.tag! 'City', address[:city]
          xml.tag! 'State', address[:state] unless address[:state].blank?
          xml.tag! 'Country', address[:country]
          
          xml.tag! 'Zip', address[:zip]
          xml.tag! 'Phone', address[:phone] unless address[:phone].blank?
          xml.tag! 'Email', options[:email] unless options[:email].blank?
        end
      end

      # Code is limited to 12 characters
      def add_item(xml, item, index)
        xml.tag! 'Item', :num => index do
          xml.tag! 'Code', item[:sku]
          xml.tag! 'Quantity', item[:quantity]
        end
      end

      def commit(action, request)
        data = ssl_post(SERVICE_URLS[action], "#{POST_VARS[action]}=#{CGI.escape(request)}")
        
        response = parse_response(action, data)
        Response.new(response[:success], response[:message], response, :test => test?)
      end
      
      def parse_response(action, data)
        case action
        when :fulfillment
          parse_fulfillment_response(data)        
        when :inventory
          parse_inventory_response(data)
        when :tracking
          parse_tracking_response(data)
        else
          raise ArgumentError, "Unknown action #{action}"
        end
      end
      
      def parse_fulfillment_response(xml)
        response = {}
        
        document = REXML::Document.new(xml)
        document.root.elements.each do |node|
          response[node.name.underscore.to_sym] = node.text
        end
        
        response[:success] = response[:status] == '0'
        response[:message] = response[:success] ? "Successfully submitted the order" : message_from(response[:error_message])        
        response
      end
      
      def parse_inventory_response(xml)
        response = {}
        response[:stock_levels] = {}
        
        document = REXML::Document.new(xml)
        document.root.elements.each do |node|
          if node.name == 'Product'
            amount = ['quantity', 'pending'].map { |a| node.attributes[a].to_i }.sum
            response[:stock_levels][node.attributes['code']] = amount
          else
            response[node.name.underscore.to_sym] = node.text
          end
        end
        
        response[:success] = test? ? response[:status] == 'Test' : response[:status] == '0'
        response[:message] = response[:success] ? "Successfully received the stock levels" : message_from(response[:error_message])
        
        response
      end
      
      def parse_tracking_response(xml)
        response = {}
        response[:tracking_numbers] = {}
        
        document = REXML::Document.new(xml)
        
        document.root.elements.each do |node|
          if node.name == 'Order'
            response[:tracking_numbers][node.attributes['id']] = node.attributes['trackingNumber'] if node.attributes["shipped"] == "YES"
          else
            response[node.name.underscore.to_sym] = node.text
          end
        end
        
        response[:success] = test? ? (response[:status] == '0' || response[:status] == 'Test') : response[:status] == '0'
        response[:message] = response[:success] ? "Successfully received the tracking numbers" : message_from(response[:error_message])
        response
      end
      
      def message_from(string)
        return if string.blank?
        string.gsub("\n", '').squeeze(" ")
      end
    end
  end
end


