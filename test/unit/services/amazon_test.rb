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
    http_response = build_mock_response(invalid_create_response, "", "500")
    @service.expects(:ssl_post).raises(ActiveMerchant::ResponseError.new(http_response))
    response = @service.fulfill('12345678', @address, @line_items, @options)
    assert !response.success?
    assert_equal "aws:Client.MissingParameter The request must contain the parameter Item.", response.params['response_comment']
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
    http_response = build_mock_response(response_from_404, "Not Found", "404")
    @service.expects(:ssl_post).raises(ActiveMerchant::ResponseError.new(http_response))
    
    response = @service.fulfill('12345678', @address, @line_items, @options)
    assert !response.success?
    assert_equal "404: Not Found", response.message
    assert_equal "404", response.params["http_code"]
    assert_equal "Not Found", response.params["http_message"]
    assert_equal response_from_404, response.params["http_body"]
  end
  
  def test_soap_fault
    http_response = build_mock_response(invalid_create_response, "500", "")
    @service.expects(:ssl_post).raises(ActiveMerchant::ResponseError.new(http_response))
    
    response = @service.fulfill('12345678', @address, @line_items, @options)
    assert !response.success?
    assert_equal 'aws:Client.MissingParameter', response.params['faultcode']
    assert_equal 'The request must contain the parameter Item.', response.params['faultstring']
    assert_equal 'aws:Client.MissingParameter The request must contain the parameter Item.', response.message
  end
  
  def test_valid_credentials
    @service.expects(:ssl_post).returns(successful_status_response)
    assert @service.valid_credentials?
  end
  
  def test_invalid_credentials
    http_response = build_mock_response(invalid_login_response, "500", "")
    @service.expects(:ssl_post).raises(ActiveMerchant::ResponseError.new(http_response))
    assert !@service.valid_credentials?
  end
  
  def test_successful_service_status
    @service.expects(:ssl_request).returns(successful_status_response)
    
    response = @service.status
    assert response.success?
  end
  
  private
  
  def build_mock_response(response, message, code = "200")
    http_response = mock(:code => code, :message => message)
    http_response.stubs(:body).returns(response)
    http_response
  end
  
  def response_for_empty_request
    '<ns:GetErrorResponse xmlns:ns="http://xino.amazonaws.com/doc/"><ns:Error><ns:Code>MissingDateHeader</ns:Code><ns:Message>Authorized request must have a "date" or "x-amz-date" header.</ns:Message></ns:Error><ns:RequestID>79ceaffe-e5a3-46a5-b36a-9ce958d68939</ns:RequestID></ns:GetErrorResponse>'
  end

  
  def invalid_login_response
    <<-XML
    <?xml version="1.0"?>
    <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:aws="http://webservices.amazon.com/AWSFault/2005-15-09">
      <env:Body>
        <env:Fault>
          <faultcode>aws:Client.InvalidClientTokenId</faultcode>
          <faultstring>The AWS Access Key Id you provided does not exist in our records.</faultstring>
          <detail>
            <aws:RequestId xmlns:aws="http://webservices.amazon.com/AWSFault/2005-15-09">51de28ce-c380-46c4-bf95-62bbf8cc4682</aws:RequestId>
          </detail>
        </env:Fault>
      </env:Body>
    </env:Envelope>      
    XML
  end
  
  def invalid_create_response
    <<-XML
<?xml version="1.0"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:aws="http://webservices.amazon.com/AWSFault/2005-15-09">
  <env:Body>
    <env:Fault>
      <faultcode>aws:Client.MissingParameter</faultcode>
      <faultstring>The request must contain the parameter Item.</faultstring>
      <detail>
        <aws:RequestId xmlns:aws="http://webservices.amazon.com/AWSFault/2005-15-09">edc852d3-937f-40f5-9d72-97b7da897b38</aws:RequestId>
      </detail>
    </env:Fault>
  </env:Body>
</env:Envelope>
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
    <ns1:CreateFulfillmentOrderResponse xmlns:ns1="http://fba-outbound.amazonaws.com/doc/2007-08-02/">
      <ns1:ResponseMetadata>
        <ns1:RequestId>ccd0116d-a476-48ac-810e-778eebe5e5e2</ns1:RequestId>
      </ns1:ResponseMetadata>
    </ns1:CreateFulfillmentOrderResponse>
  </env:Body>
</env:Envelope>
    XML
  end
  
  
  def successful_status_response
    <<-XML
<?xml version="1.0"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
  <env:Body>
    <ns1:GetServiceStatusResponse xmlns:ns1="http://fba-outbound.amazonaws.com/doc/2007-08-02/">
      <ns1:GetServiceStatusResult>
        <ns1:Status>2009-06-05T18:36:19Z service available [Version: 2007-08-02]</ns1:Status>
      </ns1:GetServiceStatusResult>
      <ns1:ResponseMetadata>
        <ns1:RequestId>1e04fabc-fbaa-4ae5-836a-f0c60f1d301a</ns1:RequestId>
      </ns1:ResponseMetadata>
    </ns1:GetServiceStatusResponse>
  </env:Body>
</env:Envelope>    
    XML
  end
end
