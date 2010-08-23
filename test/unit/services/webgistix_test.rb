require 'test_helper'

class WebgistixTest < Test::Unit::TestCase
   def setup
     Base.mode = :test
     
      @service = WebgistixService.new(
                   :login => 'cody@example.com',
                   :password => 'test'
                  )
      
      @options = { 
        :shipping_method => 'UPS Ground'
      }
      
      @address = { :name => 'Fred Brooks',
                   :address1 => '1234 Penny Lane',
                   :city => 'Jonsetown',
                   :state => 'NC',
                   :country => 'US',
                   :zip => '23456',
                   :email    => 'buyer@jadedpallet.com'
                 }
      
      @line_items = [
        { :sku => '9999',
          :quantity => 25
        }
      ]
  end 
  
  def test_missing_login
    assert_raise(ArgumentError) do
      WebgistixService.new(:password => 'test')
    end
  end
  
  def test_missing_password
    assert_raise(ArgumentError) do
      WebgistixService.new(:login => 'cody')
    end
  end
  
  def test_missing_credentials
    assert_raise(ArgumentError) do
      WebgistixService.new(:password => 'test')
    end
  end
  
  def test_credentials_present
    assert_nothing_raised do
      WebgistixService.new(
        :login    => 'cody',
        :password => 'test'
      )
    end
  end
  
  def test_successful_fulfillment
    @service.expects(:ssl_post).returns(successful_response)
    
    response = @service.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
    assert_equal WebgistixService::SUCCESS_MESSAGE, response.message
    assert_equal '619669', response.params['order_id']
  end
  
  def test_minimal_successful_fulfillment
    @service.expects(:ssl_post).returns(minimal_successful_response)
    
    response = @service.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
    assert_equal WebgistixService::SUCCESS_MESSAGE, response.message
    assert_nil response.params['order_id']
  end
  
  def test_failed_fulfillment
    @service.expects(:ssl_post).returns(failure_response)
    
    response = @service.fulfill('123456', @address, @line_items, @options)
    assert !response.success?
    assert response.test?
    assert_equal WebgistixService::FAILURE_MESSAGE, response.message
    assert_nil response.params['order_id']
    
    assert_equal 'No Address Line 1', response.params['error_0']
    assert_equal 'Unknown ItemID:  testitem', response.params['error_1']
    assert_equal 'Unknown ItemID:  WX-01-1000', response.params['error_2']
  end

  def test_stock_levels
    @service.expects(:ssl_post).returns(inventory_response)
    
    response = @service.fetch_stock_levels
    assert response.success?
    assert_equal WebgistixService::SUCCESS_MESSAGE, response.message
    assert_equal 202, response.stock_levels['GN-00-01A']
    assert_equal 199, response.stock_levels['GN-00-02A']
  end

  def test_tracking_numbers
    @service.expects(:ssl_post).returns(xml_fixture('webgistix/tracking_response'))
    
    response = @service.fetch_tracking_numbers(['AB12345', 'XY4567'])
    assert response.success?
    assert_equal WebgistixService::SUCCESS_MESSAGE, response.message
    assert_equal '1Z8E5A380396682872', response.tracking_numbers['AB12345']
    assert_nil response.tracking_numbers['XY4567']
  end
  
  def test_failed_login
    @service.expects(:ssl_post).returns(invalid_login_response)
    
    response = @service.fulfill('123456', @address, @line_items, @options)
    assert !response.success?
    assert response.test?
    assert_equal 'Access Denied', response.message
    assert_nil response.params['order_id']
    
    assert_equal 'Access Denied', response.params['error_0']
  end
  
  def test_garbage_response
    @service.expects(:ssl_post).returns(garbage_response)
    
    response = @service.fulfill('123456', @address, @line_items, @options)
    assert !response.success?
    assert response.test?
    assert_equal WebgistixService::FAILURE_MESSAGE, response.message
    assert_nil response.params['order_id']
  end
  
  def test_valid_credentials
    @service.expects(:ssl_post).returns(failure_response)
    assert @service.valid_credentials?
  end
  
  def test_invalid_credentials
    @service.expects(:ssl_post).returns(invalid_login_response)
    assert !@service.valid_credentials?
  end
    
  private
  def minimal_successful_response
    '<Completed><Success>True</Success></Completed>'
  end
  
  def successful_response
    '<Completed><Success>True</Success><OrderID>619669</OrderID></Completed>'
  end
  
  def invalid_login_response
    '<Error>Access Denied</Error>'
  end
  
  def failure_response
    '<Error>No Address Line 1</Error><Error>Unknown ItemID:  testitem</Error><Error>Unknown ItemID:  WX-01-1000</Error>'
  end
  
  def garbage_response
    '<font face="Arial" size=2>/XML/shippingTest.asp</font><font face="Arial" size=2>, line 39</font>'
  end
  
  def inventory_response
    '<InventoryXML>' +
      '<Item><ItemID>GN-00-01A</ItemID><ItemQty>202</ItemQty></Item>' +
      '<Item><ItemID>GN-00-02A</ItemID><ItemQty>199</ItemQty></Item>' +
      '</InventoryXML>'
  end
end
