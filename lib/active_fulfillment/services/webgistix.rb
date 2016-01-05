module ActiveFulfillment
  class WebgistixService < Service
  
    SERVICE_URLS = {
      :fulfillment => 'https://www.webgistix.com/XML/CreateOrder.asp',
      :inventory   => 'https://www.webgistix.com/XML/GetInventory.asp',
      :tracking    => 'https://www.webgistix.com/XML/GetTracking.asp'
    }.freeze
    
    TEST_URLS = SERVICE_URLS.dup.merge({
      :fulfillment => 'https://www.webgistix.com/XML/CreateOrderTest.asp'
    }).freeze

    SUCCESS, DUPLICATE, FAILURE = 'True'.freeze, 'Duplicate'.freeze, 'False'.freeze

    SUCCESS_MESSAGE = 'Successfully submitted the order'.freeze
    FAILURE_MESSAGE = 'Failed to submit the order'.freeze
    DUPLICATE_MESSAGE = 'This order has already been successfully submitted'.freeze

    INVALID_LOGIN = 'Invalid Credentials'.freeze
    NOT_SHIPPED = 'Not Shipped'.freeze

    TRACKING_COMPANIES = %w(UPS FedEx USPS).freeze
    
    SHIPPING_PROVIDERS = {
        'UPS Ground Shipping' => 'Ground',
        'UPS Ground' => 'Ground',
        'UPS Standard Shipping (Canada Only)' => 'Standard',
        'UPS Standard Shipping (CA & MX Only)' => 'Standard',
        'UPS 3-Business Day' => '3-Day Select',
        'UPS 2-Business Day' => '2nd Day Air',
        'UPS 2-Business Day AM' => '2nd Day Air AM',
        'UPS Next Day' => 'Next Day Air',
        'UPS Next Day Saver' => 'Next Day Air Saver',
        'UPS Next Day Early AM' => 'Next Day Air Early AM',
        'UPS Worldwide Express (Next Day)' => 'Worldwide Express',
        'UPS Worldwide Expedited (2nd Day)' => 'Worldwide Expedited',
        'UPS Worldwide Express Saver' => 'Worldwide Express Saver',
        'FedEx Priority Overnight' => 'FedEx Priority Overnight',
        'FedEx Standard Overnight' => 'FedEx Standard Overnight',
        'FedEx First Overnight' => 'FedEx First Overnight',
        'FedEx 2nd Day' => 'FedEx 2nd Day',
        'FedEx Express Saver' => 'FedEx Express Saver',
        'FedEx International Priority' => 'FedEx International Priority',
        'FedEx International Economy' => 'FedEx International Economy',
        'FedEx International First' => 'FedEx International First',
        'FedEx Ground' => 'FedEx Ground',
        'USPS Priority Mail' => 'Priority Mail',
        'USPS Priority Mail International' => 'Priority Mail International',
        'USPS Priority Mail Small Flat Rate Box' => 'Priority Mail Small Flat Rate Box',
        'USPS Priority Mail Medium Flat Rate Box' => 'Priority Mail Medium Flat Rate Box',
        'USPS Priority Mail Large Flat Rate Box' => "Priority Mail Large Flat Rate Box",
        'USPS Priority Mail Flat Rate Envelope' => 'Priority Mail Flat Rate Envelope',
        'USPS First Class Mail' => 'First Class',
        'USPS First Class International' => 'First Class International',
        'USPS Express Mail' => 'Express',
        'USPS Express Mail International' => 'Express Mail International',
        'USPS Parcel Post' => 'Parcel',
        'USPS Media Mail' => 'Media Mail'
    }.freeze

    # If a request is detected as a duplicate only the original data will be
    # used by Webgistix, and the subsequent responses will have a
    # :duplicate parameter set in the params hash.
    self.retry_safe = true

    # The first is the label, and the last is the code
    def self.shipping_methods
      SHIPPING_PROVIDERS
    end

    # Pass in the login and password for the shipwire account.
    # Optionally pass in the :test => true to force test mode
    def initialize(options = {})
      requires!(options, :login, :password)
      super
    end

    def fulfill(order_id, shipping_address, line_items, options = {})
      requires!(options, :shipping_method)
      commit :fulfillment, build_fulfillment_request(order_id, shipping_address, line_items, options)
    end

    def fetch_stock_levels(options = {})
      commit :inventory, build_inventory_request(options)
    end

    def fetch_tracking_data(order_ids, options = {})
      commit :tracking, build_tracking_request(order_ids, options)
    end

    def valid_credentials?
      response = fulfill('', {}, [], :shipping_method => '')
      response.message != INVALID_LOGIN
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

    #<?xml version="1.0"?>
    # <InventoryXML>
    #   <Password>Webgistix</Password>
    #   <CustomerID>3</CustomerID>
    # </InventoryXML>
    def build_inventory_request(options)
      xml = Builder::XmlMarkup.new :indent => 2
      xml.instruct!
      xml.tag! 'InventoryXML' do
        add_credentials(xml)
      end
    end

    #<?xml version="1.0"?>
    # <TrackingXML>
    #   <Password>Webgistix</Password>
    #   <CustomerID>3</CustomerID>
    #   <Tracking>
    #     <Order>AB12345</Order>
    #   </Tracking>
    #   <Tracking>
    #     <Order>XY4567</Order>
    #   </Tracking>
    # </TrackingXML>
    def build_tracking_request(order_ids, options)
      xml = Builder::XmlMarkup.new :indent => 2
      xml.instruct!
      xml.tag! 'TrackingXML' do
        add_credentials(xml)

        order_ids.each do |o_id|
          xml.tag! 'Tracking' do
            xml.tag! 'Order', o_id
          end
        end
      end
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
        country = ActiveUtils::Country.find(address[:country])
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

    def commit(action, request)
      url = test? ? TEST_URLS[action] : SERVICE_URLS[action]

      data = ssl_post(url, request,
        'EndPointURL'  => url,
        'Content-Type' => 'text/xml; charset="utf-8"'
      )

      response = parse_response(action, data)
      Response.new(success?(response), message_from(response), response, :test => test?)
    end

    def success?(response)
      response[:success] == SUCCESS || response[:success] == DUPLICATE
    end

    def message_from(response)
      if response[:duplicate]
        DUPLICATE_MESSAGE
      elsif success?(response)
        SUCCESS_MESSAGE
      elsif response[:error_0] == INVALID_LOGIN
        INVALID_LOGIN
      else
        FAILURE_MESSAGE
      end
    end

    def parse_response(action, xml)
      begin
        document = Nokogiri::XML("<response>#{xml}</response>")
      rescue Nokogiri::XML::SyntaxError
        return {:success => FAILURE}
      end

      case action
      when :fulfillment
        parse_fulfillment_response(document)
      when :inventory
        parse_inventory_response(document)
      when :tracking
        parse_tracking_response(document)
      else
        raise ArgumentError, "Unknown action #{action}"
      end
    end

    def parse_fulfillment_response(document)
      response = parse_errors(document)

      # Check if completed
      if completed = document.at_xpath('//Completed'.freeze)
        completed.elements.each do |e|
          response[e.name.underscore.to_sym] = e.text
        end
      else
        response[:success] = FAILURE
      end

      response[:duplicate] = response[:success] == DUPLICATE

      response
    end

    def parse_inventory_response(document)
      response = parse_errors(document)
      response[:stock_levels] = {}

      document.root.xpath('//Item'.freeze).each do |node|
        # {ItemID => 'SOME-ID', ItemQty => '101'}
        params = node.elements.to_a.each_with_object({}) {|elem, hash| hash[elem.name] = elem.text}

        response[:stock_levels][params['ItemID'.freeze]] = params['ItemQty'.freeze].to_i
      end

      response
    end

    def parse_tracking_response(document)
      response = parse_errors(document)
      response = response.merge(tracking_numbers: {}, tracking_companies: {}, tracking_urls: {})

      document.root.xpath('//Shipment'.freeze).each do |node|
        # {InvoiceNumber => 'SOME-ID', ShipmentTrackingNumber => 'SOME-TRACKING-NUMBER'}
        params = node.elements.to_a.each_with_object({}) {|elem, hash| hash[elem.name] = elem.text}

        tracking = params['ShipmentTrackingNumber'.freeze]

        unless tracking == NOT_SHIPPED
          response[:tracking_numbers][params['InvoiceNumber'.freeze]] ||= []
          response[:tracking_numbers][params['InvoiceNumber'.freeze]] << tracking
        end

        company = params['Method'.freeze].split[0] if params['Method'.freeze]
        if TRACKING_COMPANIES.include? company
          response[:tracking_companies][params['InvoiceNumber'.freeze]] ||= []
          response[:tracking_companies][params['InvoiceNumber'.freeze]] << company
        end
      end

      response
    end

    def parse_errors(document)
      response = {}

      document.xpath('//Errors/Error'.freeze).each_with_index do |e, i|
        response["error_#{i}".to_sym] = e.text
      end

      response[:success] = response.empty? ? SUCCESS : FAILURE
      response
    end
  end
end
