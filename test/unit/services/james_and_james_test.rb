require 'test_helper'

class JamesAndJamesTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @service = JamesAndJamesService.new(key: "XXX")

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
      {sku: '9999', quantity: 25}
    ]
  end

  def test_missing_key
    assert_raise(ArgumentError) do
      JamesAndJamesService.new
    end
  end

  def test_credentials_present
    assert_nothing_raised do
      JamesAndJamesService.new(key: 'XXX')
    end
  end

  def test_successful_fulfillment
    @service.expects(:ssl_post).returns(successful_response)

    response = @service.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
    # assert_equal JamesAndJamesService::SUCCESS_MESSAGE, response.message
    # assert_equal '619669', response.params['order_id']
  end

#   def test_minimal_successful_fulfillment
#     @service.expects(:ssl_post).returns(minimal_successful_response)
#
#     response = @service.fulfill('123456', @address, @line_items, @options)
#     assert response.success?
#     assert response.test?
#     assert_equal WebgistixService::SUCCESS_MESSAGE, response.message
#     assert_nil response.params['order_id']
#   end

  def test_failed_fulfillment
    @service.expects(:ssl_post).returns(failure_response)

    response = @service.fulfill('123456', @address, @line_items, @options)
    assert !response.success?
    assert response.test?
    # assert_equal WebgistixService::FAILURE_MESSAGE, response.message
    # assert_nil response.params['order_id']
    #
    # assert_equal 'No Address Line 1', response.params['error_0']
    # assert_equal 'Unknown ItemID:  testitem', response.params['error_1']
    # assert_equal 'Unknown ItemID:  WX-01-1000', response.params['error_2']
  end

  def test_stock_levels
    @service.expects(:ssl_get).returns(inventory_response)

    response = @service.fetch_stock_levels
    assert response.success?
    assert_equal 99, response.stock['AAA']
    assert_equal 9, response.stock['BBB']
  end
#
#   def test_tracking_numbers
#     @service.expects(:ssl_post).returns(xml_fixture('webgistix/tracking_response'))
#
#     response = @service.fetch_tracking_numbers(['AB12345', 'XY4567'])
#     assert response.success?
#     assert_equal WebgistixService::SUCCESS_MESSAGE, response.message
#     assert_equal ['1Z8E5A380396682872'], response.tracking_numbers['AB12345']
#     assert_nil response.tracking_numbers['XY4567']
#   end
#
#   def test_multiple_tracking_numbers
#     @service.expects(:ssl_post).returns(xml_fixture('webgistix/multiple_tracking_response'))
#     invoice_number = '#8305090.1'
#
#     response = @service.fetch_tracking_numbers([invoice_number])
#
#     assert response.success?
#     assert_equal WebgistixService::SUCCESS_MESSAGE, response.message
#     assert_equal ['345678070437428', '546932544227'], response.tracking_numbers[invoice_number]
#   end
#
#   def test_tracking_data
#     @service.expects(:ssl_post).returns(xml_fixture('webgistix/tracking_response'))
#
#     response = @service.fetch_tracking_data(['AB12345', 'XY4567'])
#
#     assert response.success?
#     assert_equal WebgistixService::SUCCESS_MESSAGE, response.message
#     assert_equal ['1Z8E5A380396682872'], response.tracking_numbers['AB12345']
#     assert_equal ['UPS'], response.tracking_companies['AB12345']
#     assert_equal({}, response.tracking_urls)
#   end
#
#   def test_failed_login
#     @service.expects(:ssl_post).returns(invalid_login_response)
#
#     response = @service.fulfill('123456', @address, @line_items, @options)
#     assert !response.success?
#     assert response.test?
#     assert_equal 'Invalid Credentials', response.message
#     assert_nil response.params['order_id']
#
#     assert_equal 'Invalid Credentials', response.params['error_0']
#   end
#
#   def test_garbage_response
#     @service.expects(:ssl_post).returns(garbage_response)
#
#     response = @service.fulfill('123456', @address, @line_items, @options)
#     assert !response.success?
#     assert response.test?
#     assert_equal WebgistixService::FAILURE_MESSAGE, response.message
#     assert_nil response.params['order_id']
#   end
#
#   def test_valid_credentials
#     @service.expects(:ssl_post).returns(failure_response)
#     assert @service.valid_credentials?
#   end
#
#   def test_invalid_credentials
#     @service.expects(:ssl_post).returns(invalid_login_response)
#     assert !@service.valid_credentials?
#   end
#
#   def test_duplicate_response_is_treated_as_success
#     response = stub(:code => 200, :body => duplicate_response, :message => '')
#     Net::HTTP.any_instance.stubs(:post).raises(ActiveMerchant::ConnectionError).returns(response)
#
#     response = @service.fulfill('123456', @address, @line_items, @options)
#     assert response.success?
#     assert response.test?
#     assert_equal WebgistixService::DUPLICATE_MESSAGE, response.message
#     assert response.params['duplicate']
#     assert_nil response.params['order_id']
#   end
#
#   def test_ensure_gateway_uses_safe_retry
#     assert @service.retry_safe
#   end
#
  private

  def minimal_successful_response
    '{"success": true, "test": true}'
  end

  def successful_response
    '{"success": true, "valid": true, "test": true}'
  end

#   def invalid_login_response
#     '<Errors><Error>Invalid Credentials</Error></Errors>'
#   end
#
  def failure_response
    # TODO Add example errors
    '{"success": false, "test": true}'
  end
#
#   def garbage_response
#     '<font face="Arial" size=2>/XML/shippingTest.asp</font><font face="Arial" size=2>, line 39</font>'
#   end
#
  def inventory_response
    '{"success": true, "stock": {"AAA": 99, "BBB": 9}, "test": true}'
  end
#
#   def duplicate_response
#     '<Completed><Success>Duplicate</Success></Completed>'
#   end
end
