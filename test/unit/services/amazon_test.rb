require 'test_helper'

class AmazonTest < Test::Unit::TestCase
   def setup
     @service = AmazonService.new(
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
  
  def test_invalid_arguments
    @service.expects(:ssl_post).returns(invalid_arguments_response)
    response = @service.fulfill('12345678', @address, @line_items, @options)
    assert !response.success?
    assert_equal '1 error: The Displayable Order Comment value cannot be blank[null].', response.params['response_comment']
  end
  
  def test_missing_order_comment
    @options.delete(:comment)
    assert_raise(ArgumentError) { @service.fulfill('12345678', @address, @line_items, @options) }
  end
  
  def test_missing_order_date
    @options.delete(:order_date)
    assert_raise(ArgumentError) { @service.fulfill('12345678', @address, @line_items, @options) }
  end
  
  def test_missing_shipping_method
    @options.delete(:shipping_method)
    assert_raise(ArgumentError) { @service.fulfill('12345678', @address, @line_items, @options) }
  end
  
  def test_404_error
    @service.expects(:ssl_post).returns(response_from_404)
    response = @service.fulfill('12345678', @address, @line_items, @options)
    assert !response.success?
    assert_equal AmazonService::MESSAGES[:error], response.message
  end
  
  def test_soap_fault
    @service.expects(:ssl_post).returns(internal_error_response)
    response = @service.fulfill('12345678', @address, @line_items, @options)
    assert !response.success?
    assert_equal 'aws:Server.InternalError', response.params['faultcode']
    assert_equal 'We encountered an internal error. Please try again.', response.params['faultstring']
    assert_equal 'We encountered an internal error. Please try again.', response.message
  end
  
  def test_valid_credentials
    @service.expects(:ssl_post).returns(internal_error_response)
    assert @service.valid_credentials?
  end
  
  def test_invalid_credentials
    @service.expects(:ssl_post).returns(failed_login_response)
    assert !@service.valid_credentials?
  end
  
  private
  def response_for_empty_request
    '<ns:GetErrorResponse xmlns:ns="http://xino.amazonaws.com/doc/"><ns:Error><ns:Code>MissingDateHeader</ns:Code><ns:Message>Authorized request must have a "date" or "x-amz-date" header.</ns:Message></ns:Error><ns:RequestID>79ceaffe-e5a3-46a5-b36a-9ce958d68939</ns:RequestID></ns:GetErrorResponse>'
  end
  
  def failed_login_response
    <<-XML
<?xml version="1.0"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:aws="http://webservices.amazon.com/AWSFault/2005-15-09"><env:Body><env:Fault><faultcode>aws:Client.InvalidAccessKeyId</faultcode><faultstring>AWS was not able to validate the provided access credentials.</faultstring><detail><aws:RequestId xmlns:aws="http://webservices.amazon.com/AWSFault/2005-15-09">9f4d8239-c274-4248-9b9f-48faef163627</aws:RequestId></detail></env:Fault></env:Body></env:Envelope>
    XML
  end
  
  def internal_error_response
    <<-XML
<?xml version="1.0"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:aws="http://webservices.amazon.com/AWSFault/2005-15-09"><env:Body><env:Fault><faultcode>aws:Server.InternalError</faultcode><faultstring>We encountered an internal error. Please try again.</faultstring><detail><aws:RequestId xmlns:aws="http://webservices.amazon.com/AWSFault/2005-15-09">bd9ff2d1-2ad6-4991-8eea-01267385c704</aws:RequestId></detail></env:Fault></env:Body></env:Envelope>
    XML
  end
  
  def response_from_404
    '<html><head><title>Apache Tomcat/5.5.9 - Error report</title><style><!--H1 {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;font-size:22px;} H2 {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;font-size:16px;} H3 {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;font-size:14px;} BODY {font-family:Tahoma,Arial,sans-serif;color:black;background-color:white;} B {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;} P {font-family:Tahoma,Arial,sans-serif;background:white;color:black;font-size:12px;}A {color : black;}A.name {color : black;}HR {color : #525D76;}--></style> </head><body><h1>HTTP Status 404 - Servlet XinoServlet is not available</h1><HR size="1" noshade="noshade"><p><b>type</b> Status report</p><p><b>message</b> <u>Servlet XinoServlet is not available</u></p><p><b>description</b> <u>The requested resource (Servlet XinoServlet is not available) is not available.</u></p><HR size="1" noshade="noshade"><h3>Apache Tomcat/5.5.9</h3></body></html>'
  end
  
  def successful_fulfillment_response
    <<-XML
<?xml version="1.0"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
  <env:Body>
    <ns1:CreateFulfillmentOrderResponse xmlns:ns1="http://fulfillment.amazonaws.com/doc/FulfillmentService/2006-12-12">
      <ns1:CreateFulfillmentOrderResult>
        <ns1:Response>
          <ns1:ResponseStatus>Accepted</ns1:ResponseStatus>
        </ns1:Response>
        <ns1:Request>
          <ns1:CreateFulfillmentOrderRequest>
            <ns1:Credentials>
              <ns1:Email>merchant@example.com</ns1:Email>
              <ns1:Password>password</ns1:Password>
            </ns1:Credentials>
            <ns1:MerchantFulfillmentOrderId>123456</ns1:MerchantFulfillmentOrderId>
            <ns1:DisplayableOrderId>123456</ns1:DisplayableOrderId>
            <ns1:DisplayableOrderDate>2007-10-21T20:15:28Z</ns1:DisplayableOrderDate>
            <ns1:DisplayableOrderComment>Delayed due to tornados</ns1:DisplayableOrderComment>
            <ns1:DeliverySLA>Standard</ns1:DeliverySLA>
            <ns1:DestinationAddress>
              <ns1:Name>Jaded Pixel Technologies</ns1:Name>
              <ns1:Line1>5 Elm St.</ns1:Line1>
              <ns1:Line2>#500</ns1:Line2>
              <ns1:City>Beverly Hills</ns1:City>
              <ns1:StateOrRegion>CA</ns1:StateOrRegion>
              <ns1:CountryCode>US</ns1:CountryCode>
              <ns1:PostalCode>90210</ns1:PostalCode>
            </ns1:DestinationAddress>
            <ns1:Items>
              <ns1:MerchantSKU>SETTLERS</ns1:MerchantSKU>
              <ns1:MerchantFulfillmentOrderItemId>0</ns1:MerchantFulfillmentOrderItemId>
              <ns1:Quantity>1</ns1:Quantity>
              <ns1:DisplayableComment>Awesome</ns1:DisplayableComment>
            </ns1:Items>
          </ns1:CreateFulfillmentOrderRequest>
          <ns1:IsValid>True</ns1:IsValid>
        </ns1:Request>
      </ns1:CreateFulfillmentOrderResult>
    </ns1:CreateFulfillmentOrderResponse>
  </env:Body>
</env:Envelope>
    XML
  end
  
  def invalid_arguments_response
    <<-XML
<?xml version="1.0"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
  <env:Body>
    <ns1:CreateFulfillmentOrderResponse xmlns:ns1="http://fulfillment.amazonaws.com/doc/FulfillmentService/2006-12-12">
      <ns1:CreateFulfillmentOrderResult>
        <ns1:Response>
          <ns1:ResponseStatus>InvalidArguments</ns1:ResponseStatus>
          <ns1:ResponseComment>1 error:
The Displayable Order Comment value cannot be blank[null].
</ns1:ResponseComment>
        </ns1:Response>
        <ns1:Request>
          <ns1:CreateFulfillmentOrderRequest>
            <ns1:Credentials>
              <ns1:Email>merchant@example.com</ns1:Email>
              <ns1:Password>password</ns1:Password>
            </ns1:Credentials>
            <ns1:MerchantFulfillmentOrderId>12345678</ns1:MerchantFulfillmentOrderId>
            <ns1:DisplayableOrderId>12345678</ns1:DisplayableOrderId>
            <ns1:DisplayableOrderDate>2007-10-21T21:10:48Z</ns1:DisplayableOrderDate>
            <ns1:DeliverySLA>Standard</ns1:DeliverySLA>
            <ns1:DestinationAddress>
              <ns1:Name>Jaded Pixel Technologies</ns1:Name>
              <ns1:Line1>5 Elm St.</ns1:Line1>
              <ns1:Line2>#500</ns1:Line2>
              <ns1:City>Beverly Hills</ns1:City>
              <ns1:StateOrRegion>CA</ns1:StateOrRegion>
              <ns1:CountryCode>US</ns1:CountryCode>
              <ns1:PostalCode>90210</ns1:PostalCode>
            </ns1:DestinationAddress>
            <ns1:Items>
              <ns1:MerchantSKU>SETTLERS1</ns1:MerchantSKU>
              <ns1:MerchantFulfillmentOrderItemId>0</ns1:MerchantFulfillmentOrderItemId>
              <ns1:Quantity>1</ns1:Quantity>
              <ns1:DisplayableComment>Awesome</ns1:DisplayableComment>
            </ns1:Items>
          </ns1:CreateFulfillmentOrderRequest>
          <ns1:IsValid>True</ns1:IsValid>
        </ns1:Request>
      </ns1:CreateFulfillmentOrderResult>
    </ns1:CreateFulfillmentOrderResponse>
  </env:Body>
</env:Envelope>
    XML
  end
end
