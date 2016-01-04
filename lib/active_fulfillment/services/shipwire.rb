require 'cgi'

module ActiveFulfillment
  class ShipwireService < Service

    SERVICE_URLS = { :fulfillment  => 'https://api.shipwire.com/exec/FulfillmentServices.php',
                     :inventory    => 'https://api.shipwire.com/exec/InventoryServices.php',
                     :tracking     => 'https://api.shipwire.com/exec/TrackingServices.php'
                   }.freeze

    SCHEMA_URLS = { :fulfillment => 'http://www.shipwire.com/exec/download/OrderList.dtd',
                    :inventory   => 'http://www.shipwire.com/exec/download/InventoryUpdate.dtd',
                    :tracking    => 'http://www.shipwire.com/exec/download/TrackingUpdate.dtd'
                  }.freeze

    POST_VARS = { :fulfillment => 'OrderListXML',
                  :inventory   => 'InventoryUpdateXML',
                  :tracking    => 'TrackingUpdateXML'
                }.freeze

    WAREHOUSES = { 'CHI' => 'Chicago',
                   'LAX' => 'Los Angeles',
                   'REN' => 'Reno',
                   'VAN' => 'Vancouver',
                   'TOR' => 'Toronto',
                   'UK'  => 'United Kingdom'
                 }.freeze

    INVALID_LOGIN = /(Error with Valid Username\/EmailAddress and Password Required)|(Could not verify Username\/EmailAddress and Password combination)/

    SHIPPING_METHODS = {
      '1 Day Service' => '1D',
      '2 Day Service' => '2D',
      'Ground Service' => 'GD',
      'Freight Service' => 'FT',
      'International' => 'INTL'
    }.freeze

    class_attribute :affiliate_id

    # The first is the label, and the last is the code
    def self.shipping_methods
      SHIPPING_METHODS
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

    def fetch_tracking_data(order_ids, options = {})
      commit :tracking, build_tracking_request(order_ids)
    end

    def valid_credentials?
      response = fetch_tracking_numbers([])
      response.message !~ INVALID_LOGIN
    end

    def test_mode?
      true
    end

    def include_pending_stock?
      @options[:include_pending_stock]
    end

    def include_empty_stock?
      @options[:include_empty_stock]
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
        xml.tag! 'IncludeEmpty' if include_empty_stock?
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
      xml.tag! 'AffiliateId', affiliate_id if affiliate_id.present?
    end

    def add_order(xml, order_id, shipping_address, line_items, options)
      xml.tag! 'Order', :id => order_id do
        xml.tag! 'Warehouse', options[:warehouse] || '00'

        add_address(xml, shipping_address, options)
        xml.tag! 'Shipping', options[:shipping_method] unless options[:shipping_method].blank?

        Array(line_items).each_with_index do |line_item, index|
          add_item(xml, line_item, index)
        end
        xml.tag! 'Note' do
          xml.cdata! options[:note] unless options[:note].blank?
        end
      end
    end

    def add_address(xml, address, options)
      xml.tag! 'AddressInfo', :type => 'Ship' do
        xml.tag! 'Name' do
          xml.tag! 'Full', address[:name]
        end

        xml.tag! 'Address1', address[:address1]
        xml.tag! 'Address2', address[:address2]

        xml.tag! 'Company', address[:company]

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
      Parsing.with_xml_document(xml) do |document, response|
        document.root.try do |root_document|
          root_document.elements.each do |node|
            response[node.name.underscore.to_sym] = node.text.strip
          end
        end

        response[:success] = response[:status] == '0'
        response[:message] = response[:success] ? 'Successfully submitted the order' : message_from(response[:error_message])
        response
      end
    end

    def compute_stock_levels(document)
      products = document.xpath('//Product')
      items = {}
      products.each do |product|
        qty = product.at_xpath('@quantity').child.content.to_i
        code = product.at_xpath('@code').child.content
        if include_pending_stock?
          pending_qty = product.at_xpath('@pending').child.content.to_i
          items[code] = qty + pending_qty
        else
          items[code] = qty
        end
      end
      items
    end

    def parse_inventory_response(xml)
      response = { stock_levels: {} }
      Parsing.with_xml_document(xml, response) do |document|
        status = document.at_xpath('//Status').child.content
        total_products = document.at_xpath('//TotalProducts').child.content
        success = test? ? status == 'Test' : status == '0'
        message = success ? 'Successfully received the stock levels' : document.at_xpath('//ErrorMessage').child.content

        {
          status: status,
          total_products: total_products,
          stock_levels: compute_stock_levels(document),
          message: message,
          success: success
        }
      end
    end

    def tracking_details(xml)
      response = {
        tracking_numbers: {},
        tracking_companies: {},
        tracking_urls: {}
      }

      Parsing.with_xml_document(xml, response) do |document, response|
        document.root.try do |root_document|
          root_document.elements.each do |node|
            if node.name == 'Order'
              if node.attributes['shipped'].text == "YES"
                node_tracking = node.at_css("TrackingNumber")
                unless node_tracking.nil? 
                  node_id = node.attributes['id'].text.strip
                  tracking_number = node_tracking.text.strip
                  response[:tracking_numbers][node_id] = [tracking_number]

                  tracking_company = node_tracking.attributes['carrier'].try { |item| item.text.strip }
                  response[:tracking_companies][node_id] = [tracking_company] if tracking_company

                  tracking_url = node_tracking.attributes['href'].try { |item| item.text.strip }
                  response[:tracking_urls][node_id] = [tracking_url] if tracking_url
                end
              end
            else
              response[node.name.underscore.to_sym] = node.text.strip
            end
          end
        end

        response
      end
    end

    def parse_tracking_response(xml)
      response = tracking_details(xml)
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
