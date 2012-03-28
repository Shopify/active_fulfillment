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
     
     @address = { :name => 'Johnny Chase',
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
