require 'test_helper'

class AmazonMarketplaceWebServiceTest < Test::Unit::TestCase
  def setup
    @service = AmazonMarketplaceWebService.new(
                                               :login => 'l',
                                               :password => 'p'
                                               )
    
    @options = { 
      :shipping_method => 'Standard',
      :order_date => Time.now.utc.yesterday,
      :comment => "Delayed due to tornados"
    }
    
    @address = { 
      :name => 'Johnny Chase',
      :address1 => '100 Information Super Highway',
      :address2 => 'Suite 66',
      :city => 'Beverly Hills',
      :state => 'CA',
      :country => 'US',
      :zip => '90210',
      :phone => "(555)555-5555"
    }

    @canadian_address = { 
      :name => 'Johnny Bouchard',
      :address1 => '100 Canuck St',
      :address2 => 'Room 56',
      :city => 'Ottawa',
      :state => 'ON',
      :country => 'CA',
      :zip => 'h0h0h0',
      :phone => "(555)555-5555"
    }
    
    @line_items = [
                   { :sku => 'SETTLERS1',
                     :quantity => 1,
                     :comment => 'Awesome'
                   }
                  ]
  end

  def test_get_default_fulfillment_gateway
    assert_equal AmazonMarketplaceWebService::ENDPOINTS[:us], @service.endpoint
  end

  def test_create_service_with_different_fulfillment_gateway
    service = AmazonMarketplaceWebService.new(:login => 'l', :password => 'p', :endpoint => :jp)
    assert_equal AmazonMarketplaceWebService::ENDPOINTS[:jp], service.endpoint
  end

  def test_build_basic_api_query
    options = {
      "Action" => "SubmitFeed",
      "FeedType" => "_POST_INVENTORY_AVAILABILITY_DATA_",
      "Merchant" => "SuperMerchant123"
    }
    expected_keys = ["AWSAccessKeyId", "Action", "FeedType", "Merchant", "SignatureMethod", "SignatureVersion", "Timestamp", "Version"]
    opts = @service.build_basic_api_query(options)
    assert_equal expected_keys.sort, opts.keys.map(&:to_s).sort
    assert_equal "l", opts["AWSAccessKeyId"]
    assert_equal AmazonMarketplaceWebService::SIGNATURE_VERSION, opts["SignatureVersion"]
    assert_equal "Hmac#{AmazonMarketplaceWebService::SIGNATURE_METHOD}", opts["SignatureMethod"]
    assert_equal AmazonMarketplaceWebService::VERSION, opts["Version"]
  end

  def test_build_inventory_list_request
    skus = ["CITADELS", "INNOVATION", "JAIPUR"]
    request_params = @service.build_inventory_list_request(:skus => skus)
    keys = request_params.keys

    assert keys.include?("SellerSkus.member.1")
    assert keys.include?("SellerSkus.member.2")
    assert keys.include?("SellerSkus.member.3")
    assert_equal 'CITADELS', request_params['SellerSkus.member.1']
    assert_equal 'INNOVATION', request_params['SellerSkus.member.2']
    assert_equal 'JAIPUR', request_params["SellerSkus.member.3"]
  end

  def test_create_signature
    service = AmazonMarketplaceWebService.new(:login => "0PExampleR2", :password => "sekrets")
    expected_signature = "39XxH6iKLysjjDmWZSkyr2z8iSxfECHBYE1Pd0Qqpwo%3D"
    options = {
      "AWSAccessKeyId" => "0PExampleR2",
      "Action" => "SubmitFeed",
      "FeedType" => "_POST_INVENTORY_AVAILABILITY_DATA_",
      "Marketplace" => "ATExampleER",
      "Merchant" => "A1ExampleE6", 
      "SignatureMethod" => "HmacSHA256",
      "SignatureVersion" => "2",
      "Timestamp" => "2009-08-20T01:10:27.607Z",
      "Version" => "2009-01-01"
    }

    uri = URI.parse("https://#{AmazonMarketplaceWebService::ENDPOINTS[:us]}")
    
    assert_equal expected_signature, service.sign(:POST, uri, options)
  end

  def test_verify_amazon_response
    service = AmazonMarketplaceWebService.new(:login => "AKIAFJPPO5KLY6G4XO7Q", :password => "aaa")
    string_signed_by_amazon = "POST\nhttps://www.vendor.com/mwsApp1\n/orders/listRecentOrders.jsp?sessionId=123"
    string_signed_by_amazon += "\nAWSAccessKeyId=AKIAFJPPO5KLY6G4XO7Q&Marketplace=ATVPDKIKX0DER&Merchant=A047950713KM6AGKQCBRD&SignatureMethod=HmacSHA256&SignatureVersion=2"
    assert service.amazon_request?(string_signed_by_amazon, "b0hxWov1RfBOqNk77UDfNRRZmf3tkdM7vuNa%2FolfnWg%3D")
  end

  def test_build_address
    expected_items = {
      "DestinationAddress.Name" => @address[:name],
      "DestinationAddress.Line1" => @address[:address1],
      "DestinationAddress.Line2" => @address[:address2],
      "DestinationAddress.City" => @address[:city],
      "DestinationAddress.StateOrProvinceCode" => @address[:state],
      "DestinationAddress.CountryCode" => @address[:country],
      "DestinationAddress.PostalCode" => @address[:zip],
      "DestinationAddress.PhoneNumber" => @address[:phone]
    }
    assert_equal expected_items, @service.build_address(@address)
  end

  def test_build_address_upcases_postal_code
    address = @service.build_address(@canadian_address)
    assert_equal address["DestinationAddress.PostalCode"], "H0H0H0" 
  end

  def test_build_address_with_missing_fields
    expected_items = {
      "DestinationAddress.Name" => @address[:name],
      "DestinationAddress.Line1" => @address[:address1],
      "DestinationAddress.City" => @address[:city],
      "DestinationAddress.StateOrProvinceCode" => @address[:state],
      "DestinationAddress.CountryCode" => @address[:country],
      "DestinationAddress.PostalCode" => @address[:zip],
      "DestinationAddress.PhoneNumber" => @address[:phone]
    }
    @address[:address2] = ""

    assert_equal expected_items, @service.build_address(@address)
  end

  def test_integrated_registration_url_creation
    service = AmazonMarketplaceWebService.new(:login => "AKIAFJPPO5KLY6G4XO7Q", :password => "aaa", :app_id => "1014f5ad-c359-4e86-8e50-bb8f8e431a9")
    options = {
      "returnPathAndParameters" => "/orders/listRecentOrders.jsp?sessionId=123"
    }
    expected_registration_url = "#{AmazonMarketplaceWebService::REGISTRATION_URI.to_s}?AWSAccessKeyId=AKIAFJPPO5KLY6G4XO7Q&SignatureMethod=HmacSHA256&SignatureVersion=2&id=1014f5ad-c359-4e86-8e50-bb8f8e431a9&returnPathAndParameters=%2Forders%2FlistRecentOrders.jsp%3FsessionId%3D123&Signature=zpZyHd8rMf5gg5rpO5ri5RGUi0kks03ZkhAtPm4npVk%3D"
    assert_equal expected_registration_url, service.registration_url(options)
  end

  def test_build_items
    expected_items = {
      "Items.member.1.DisplayableComment" => "Awesome",
      "Items.member.1.Quantity" => 1,
      "Items.member.1.SellerFulfillmentOrderItemId" => "SETTLERS1",
      "Items.member.1.SellerSKU" => "SETTLERS1"
    }

    actual_items = @service.build_items(@line_items)
                        
    assert_equal expected_items, @service.build_items(@line_items)
  end

  def test_successful_fulfillment
    @service.expects(:ssl_post).returns(successful_fulfillment_response)
    response = @service.fulfill('12345678', @address, @line_items, @options)
    assert response.success?
  end

  def test_invalid_arguments
    http_response = build_mock_response(invalid_params_response, "", 500)
    @service.expects(:ssl_post).raises(ActiveMerchant::ResponseError.new(http_response))
    response = @service.fulfill('12345678', @address, @line_items, @options)
    assert !response.success?
    assert_equal "MalformedInput: timestamp must follow ISO8601", response.params['response_comment']
  end

  def test_missing_order_date
    @options.delete(:order_date)
    assert_raise(ArgumentError) { @service.fulfill('12345678', @address, @line_items, @options) }
  end

  def test_missing_shipping_method
    @options.delete(:shipping_method)
    assert_raise(ArgumentError) { @service.fulfill('12345678', @address, @line_items, @options) }
  end

  def test_get_service_status
    @service.expects(:ssl_post).returns(successful_status_response)

    response = @service.status
    assert response.success?
  end

  def test_get_inventory
    @service.expects(:ssl_post).returns(xml_fixture('amazon_mws/inventory_list_inventory_supply'))

    response = @service.fetch_stock_levels
    assert response.success?
    assert_equal 202, response.stock_levels['GN-00-01A']
    assert_equal 199, response.stock_levels['GN-00-02A']
  end

  def test_get_inventory_multipage
    @service.expects(:ssl_post).with() { |uri, query, headers|
      query.include?('ListInventorySupply') && !query.include?('ListInventorySupplyByNextToken')
    }.returns(xml_fixture('amazon_mws/inventory_list_inventory_supply_by_next_token'))
    
    @service.expects(:ssl_post).with() { |uri, query, headers|
      query.include?('ListInventorySupplyByNextToken') && query.include?('NextToken')
    }.returns(xml_fixture('amazon_mws/inventory_list_inventory_supply'))

    response = @service.fetch_stock_levels
    assert response.success?
    
    assert_equal 202, response.stock_levels['GN-00-01A']
    assert_equal 199, response.stock_levels['GN-00-02A']
    assert_equal 0, response.stock_levels['GN-01-01A']
    assert_equal 5259, response.stock_levels['GN-01-02A']
  end

  def test_get_next_page_builds_query_with_proper_params
    @service.expects(:build_basic_api_query).with(:NextToken => "abracadabra", :Action => 'ListInventorySupplyByNextToken')
    @service.send(:build_next_inventory_list_request, "abracadabra")
  end

  def test_fetch_tracking_numbers
    @service.expects(:ssl_post).twice.
      returns(xml_fixture('amazon_mws/fulfillment_get_fulfillment_order')).
      returns(xml_fixture('amazon_mws/fulfillment_get_fulfillment_order_2'))

    response = @service.fetch_tracking_numbers(['extern_id_1154539615776', 'extern_id_1154539615777'])
    assert response.success?
    assert_equal %w{93ZZ00}, response.tracking_numbers['extern_id_1154539615776']
    assert_nil response.tracking_numbers['extern_id_1154539615777']
  end


  def test_fetch_multiple_tracking_numbers
    @service.expects(:ssl_post).returns(xml_fixture('amazon_mws/fulfillment_get_fullfillment_order_with_multiple_tracking_numbers'))

    response = @service.fetch_tracking_numbers(['extern_id_1154539615776'])
    assert response.success?
    assert_equal %w{93YY00 93ZZ00}, response.tracking_numbers['extern_id_1154539615776']
  end

  def test_that_generated_requests_do_not_double_escape_spaces
    fulfillment_request = @service.send(:build_fulfillment_request, "12345", @address, @line_items, @options)
    result = @service.build_full_query(:post, URI.parse("http://example.com/someservice/2011"), fulfillment_request)

    assert !result.include?('%2520')
  end

  def test_fetch_tracking_numbers_ignores_not_found
    response = mock('response')
    response.stubs(:code).returns(500)
    response.stubs(:message).returns("Internal Server Error")
    response.stubs(:body).returns(xml_fixture('amazon_mws/tracking_response_not_found'))

    @service.expects(:ssl_post).times(3).
      returns(xml_fixture('amazon_mws/fulfillment_get_fulfillment_order')).
      raises(ActiveMerchant::ResponseError.new(response)).
      returns(xml_fixture('amazon_mws/fulfillment_get_fulfillment_order_2'))

    response = @service.fetch_tracking_numbers(['extern_id_1154539615776', 'dafdfafsdafdafasdfa', 'extern_id_1154539615777'])
    assert response.success?
    assert_equal %w{93ZZ00}, response.tracking_numbers['extern_id_1154539615776']
  end

  def test_fetch_tracking_numbers_aborts_on_error
    response = mock('response')
    response.stubs(:code).returns(500)
    response.stubs(:message).returns("Internal Server Error")
    response.stubs(:body).returns(xml_fixture('amazon_mws/tracking_response_error'))

    @service.expects(:ssl_post).twice.
      returns(xml_fixture('amazon_mws/fulfillment_get_fulfillment_order')).
      raises(ActiveMerchant::ResponseError.new(response))

    response = @service.fetch_tracking_numbers(['extern_id_1154539615776', 'ERROR', 'extern_id_1154539615777'])
    assert !response.success?
    assert_equal 'Something has gone terribly wrong!', response.faultstring
  end

  def test_404_error
    http_response = build_mock_response(response_from_404, "Not Found", "404")
    @service.expects(:ssl_post).raises(ActiveMerchant::ResponseError.new(http_response))

    response = @service.fulfill('987654321', @address, @line_items, @options)
    assert !response.success?

    assert_equal "404: Not Found", response.response_comment
    assert_equal "404", response.http_code
    assert_equal "Not Found", response.http_message
    assert_equal response_from_404, response.http_body
  end

  def test_building_address_skips_nil_values
    @address[:address2] = nil
    assert_nothing_raised do
      @service.send(:build_address, @address)
    end
  end

  def test_building_a_full_query_does_not_cause_query_to_fail
    @address[:company] = "Powerthirst Inc."

    constructed_address = @service.send(:build_address, @address)
    assert !constructed_address[nil]
  end

  private
  def build_mock_response(response, message, code = "200")
    http_response = mock(:code => code, :message => message)
    http_response.stubs(:body).returns(response)
    http_response
  end

  def successful_fulfillment_response
    <<-XML
<?xml version="1.0"?>
<CreateFulfillmentOrderResponse
xmlns="http://mws.amazonaws.com/FulfillmentOutboundShipment/2010-10-01/">
  <ResponseMetadata>
    <RequestId>d95be26c-16cf-4bbc-ab58-dce89fd4ac53</RequestId>
  </ResponseMetadata>
</CreateFulfillmentOrderResponse>
    XML
  end

  def successful_status_response
    <<-XML
<?xml version="1.0"?>
  <GetServiceStatusResponse
xmlns="http://mws.amazonaws.com/FulfillmentOutboundShipment/2010-10-01/">
    <GetServiceStatusResult>
      <Status>GREEN_I</Status>
      <Timestamp>2010-11-01T21:38:09.676Z</Timestamp>
      <MessageId>173964729I</MessageId>
      <Messages>
        <Message>
          <Locale>en_US</Locale>
          <Text>We are experiencing high latency in UK because of heavy
traffic.</Text>
        </Message>
      </Messages>
    </GetServiceStatusResult>
    <ResponseMetadata>
      <RequestId>d80c6c7b-f7c7-4fa7-bdd7-854711cb3bcc</RequestId>
    </ResponseMetadata>
  </GetServiceStatusResponse>
    XML
  end

  def response_from_404
    '<html><head><title>Apache Tomcat</title></head><body>That was not found</body></html>'
  end

  def invalid_params_response
    <<-XML
    <ErrorResponse xmlns="http://mws.amazonaws.com/FulfillmentInventory/2010-10-01/">
      <Error>
        <Type>Sender</Type>
        <Code>MalformedInput</Code>
        <Message>timestamp must follow ISO8601</Message>
      </Error>
      <RequestId>e71f72f5-3df6-4306-bb67-9f55bd9d9665</RequestId>
    </ErrorResponse>
    XML
  end
end
