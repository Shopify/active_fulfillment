require 'test_helper'

class WebgistixTest < Minitest::Test
  include ActiveFulfillment::Test::Fixtures

  def setup
    ActiveFulfillment::Base.mode = :test

    @service = ActiveFulfillment::WebgistixService.new(
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
    assert_raises(ArgumentError) do
      ActiveFulfillment::WebgistixService.new(:password => 'test')
    end
  end

  def test_missing_password
    assert_raises(ArgumentError) do
      ActiveFulfillment::WebgistixService.new(:login => 'cody')
    end
  end

  def test_missing_credentials
    assert_raises(ArgumentError) do
      ActiveFulfillment::WebgistixService.new(:password => 'test')
    end
  end

  def test_credentials_present
    assert ActiveFulfillment::WebgistixService.new(
      :login    => 'cody',
      :password => 'test'
    )
  end

  def test_successful_fulfillment
    @service.expects(:ssl_post).returns(xml_fixture('webgistix/successful_response'))

    response = @service.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
    assert_equal ActiveFulfillment::WebgistixService::SUCCESS_MESSAGE, response.message
    assert_equal '619669', response.params['order_id']
  end

  def test_minimal_successful_fulfillment
    @service.expects(:ssl_post).returns(xml_fixture('webgistix/minimal_successful_response'))

    response = @service.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
    assert_equal ActiveFulfillment::WebgistixService::SUCCESS_MESSAGE, response.message
    assert_nil response.params['order_id']
  end

  def test_failed_fulfillment
    @service.expects(:ssl_post).returns(xml_fixture('webgistix/failure_response'))

    response = @service.fulfill('123456', @address, @line_items, @options)
    assert !response.success?
    assert response.test?
    assert_equal ActiveFulfillment::WebgistixService::FAILURE_MESSAGE, response.message
    assert_nil response.params['order_id']

    assert_equal 'No Address Line 1', response.params['error_0']
    assert_equal 'Unknown ItemID:  testitem', response.params['error_1']
    assert_equal 'Unknown ItemID:  WX-01-1000', response.params['error_2']
  end

  def test_stock_levels
    @service.expects(:ssl_post).returns(xml_fixture('webgistix/inventory_response'))

    response = @service.fetch_all_stock_levels
    assert response.success?
    assert_equal ActiveFulfillment::WebgistixService::SUCCESS_MESSAGE, response.message
    assert_equal 202, response.stock_levels['GN-00-01A']
    assert_equal 199, response.stock_levels['GN-00-02A']
  end

  def test_tracking_numbers
    @service.expects(:ssl_post).returns(xml_fixture('webgistix/tracking_response'))

    response = @service.fetch_tracking_numbers(['AB12345', 'XY4567'])
    assert response.success?
    assert_equal ActiveFulfillment::WebgistixService::SUCCESS_MESSAGE, response.message
    assert_equal ['1Z8E5A380396682872'], response.tracking_numbers['AB12345']
    assert_nil response.tracking_numbers['XY4567']
  end

  def test_multiple_tracking_numbers
    @service.expects(:ssl_post).returns(xml_fixture('webgistix/multiple_tracking_response'))
    invoice_number = '#8305090.1'

    response = @service.fetch_tracking_numbers([invoice_number])

    assert response.success?
    assert_equal ActiveFulfillment::WebgistixService::SUCCESS_MESSAGE, response.message
    assert_equal ['345678070437428', '546932544227'], response.tracking_numbers[invoice_number]
  end

  def test_tracking_data
    @service.expects(:ssl_post).returns(xml_fixture('webgistix/tracking_response'))

    response = @service.fetch_tracking_numbers(['AB12345', 'XY4567'])

    assert response.success?
    assert_equal ActiveFulfillment::WebgistixService::SUCCESS_MESSAGE, response.message
    assert_equal ['1Z8E5A380396682872'], response.tracking_numbers['AB12345']
    assert_equal ['UPS'], response.tracking_companies['AB12345']
    assert_equal({}, response.tracking_urls)
  end

  def test_failed_login
    @service.expects(:ssl_post).returns(xml_fixture('webgistix/invalid_login_response'))

    response = @service.fulfill('123456', @address, @line_items, @options)
    assert !response.success?
    assert response.test?
    assert_equal 'Invalid Credentials', response.message
    assert_nil response.params['order_id']

    assert_equal 'Invalid Credentials', response.params['error_0']
  end

  def test_garbage_response
    garbage = '<font face="Arial" size=2>/XML/shippingTest.asp</font><font face="Arial" size=2>, line 39</font>'
    @service.expects(:ssl_post).returns(garbage)

    response = @service.fulfill('123456', @address, @line_items, @options)
    assert !response.success?
    assert response.test?
    assert_equal ActiveFulfillment::WebgistixService::FAILURE_MESSAGE, response.message
    assert_nil response.params['order_id']
  end

  def test_valid_credentials
    @service.expects(:ssl_post).returns(xml_fixture('webgistix/failure_response'))
    assert @service.valid_credentials?
  end

  def test_invalid_credentials
    @service.expects(:ssl_post).returns(xml_fixture('webgistix/invalid_login_response'))
    assert !@service.valid_credentials?
  end

  def test_duplicate_response_is_treated_as_success
    response = stub(:code => 200, :body => xml_fixture('webgistix/duplicate_response'), :message => '')
    Net::HTTP.any_instance.stubs(:post).raises(ActiveUtils::ConnectionError).returns(response)

    response = @service.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
    assert_equal ActiveFulfillment::WebgistixService::DUPLICATE_MESSAGE, response.message
    assert response.params['duplicate']
    assert_nil response.params['order_id']
  end

  def test_ensure_gateway_uses_safe_retry
    assert @service.retry_safe
  end
end
