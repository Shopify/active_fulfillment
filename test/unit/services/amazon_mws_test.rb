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
      :zip => '90210'
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

  def test_create_signature
    service = AmazonMarketplaceWebService.new(:login => "0PExampleR2", :password => "sekrets")
    expected_signature = "39XxH6iKLysjjDmWZSkyr2z8iSxfECHBYE1Pd0Qqpwo="
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

  def test_build_address
    expected_items = {
      "DestinationAddress.Name" => @address[:name].gsub(' ', '%20'),
      "DestinationAddress.Line1" => @address[:address1].gsub(' ', '%20'),
      "DestinationAddress.Line2" => @address[:address2].gsub(' ', '%20'),
      "DestinationAddress.City" => @address[:city].gsub(' ', '%20'),
      "DestinationAddress.StateOrProvinceCode" => @address[:state].gsub(' ', '%20'),
      "DestinationAddress.CountryCode" => @address[:country].gsub(' ', '%20'),
      "DestinationAddress.PostalCode" => @address[:zip].gsub(' ', '%20')
    }
    assert_equal expected_items, @service.build_address(@address)
  end

  def test_build_items
    expected_items = {
      "Item.member.1.Quantity" => "1",
      "Item.member.1.SellerSKU" => "SETTLERS1",
      "Item.member.1.DisplayableComment" => "Awesome"
    }
                        
    assert_equal expected_items, @service.build_items(@line_items)
  end

  def test_successful_fulfillment
    @service.expects(:ssl_post).returns(successful_fulfillment_response)
    response = @service.fulfill('12345678', @address, @line_items, @options)
    assert response.success?
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
end
