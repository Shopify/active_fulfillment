require 'test_helper'

class RemoteAmazonTest < Test::Unit::TestCase
  # AmazonService.logger = Logger.new(STDOUT)
  # AmazonService.wiredump_device = STDOUT
  
  AmazonService.ssl_strict = false
  
  # In order for these tests to work you must have a live account with Amazon.
  # You can sign up at http://amazonservices.com/fulfillment/
  # The SKUs must also exist in your inventory. You do not want the SKUs you
  # use for testing to actually have inventory in the Amazon warehouse, or else
  # the shipments will actually be fulfillable
  def setup
    @service = AmazonService.new( fixtures(:amazon) )

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
       { :sku => 'SETTLERS8',
         :quantity => 1 #,
         #:comment => 'Awesome'
       }
     ]
  end

  def test_successful_order_submission
    response = @service.fulfill(generate_order_id, @address, @line_items, @options)
    assert response.success?
    assert !response.test?
  end
  
  
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
  def test_order_multiple_line_items
    @line_items.push(
      { :sku => 'CARCASSONNE',
        :quantity => 2
       }
    )
    
    response = @service.fulfill(generate_order_id, @address, @line_items, @options)
    assert response.success?
  end
  
  def test_invalid_credentials_during_fulfillment
    service = AmazonService.new(
      :login => 'y',
      :password => 'p')
    
    response = service.fulfill(generate_order_id, @address, @line_items, @options)
    assert !response.success?
    assert_equal "aws:Client.InvalidClientTokenId The AWS Access Key Id you provided does not exist in our records.", response.message
  end
  
  def test_list_orders
    response = @service.fetch_current_orders
    assert response.success?
  end
  
  def test_list_orders_fails
  end
  
  def test_valid_credentials
    assert @service.valid_credentials?
  end
  
  def test_invalid_credentials
    service = AmazonService.new(
      :login => 'your@email.com',
      :password => 'password')
    assert !service.valid_credentials?
  end
  
  
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
  def test_get_status_fails
    service = AmazonService.new(
      :login => 'your@email.com',
      :password => 'password')
    response = service.status
    assert !response.success?
    assert_equal "aws:Client.InvalidClientTokenId The AWS Access Key Id you provided does not exist in our records.", response.message
  end
  
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
  def test_get_status
    service = AmazonService.new(fixtures(:amazon))
    response = service.status
    assert response.success?
  end
  
end