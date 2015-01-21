require 'test_helper'

class JamesAndJamesTest < Minitest::Test
  def setup
    ActiveFulfillment::Base.mode = :test

    @service = ActiveFulfillment::JamesAndJamesService.new(subdomain: "client", key: "secret")

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
    assert_raises(ArgumentError) do
      ActiveFulfillment::JamesAndJamesService.new
    end
  end

  def test_credentials_present
    assert ActiveFulfillment::JamesAndJamesService.new(subdomain: "client", key: "secret")
  end

  def test_successful_fulfillment
    @service.expects(:ssl_post).returns(SUCCESSFUL_RESPONSE)

    @options[:billing_address] = @address
    response = @service.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
  end

  def test_failed_fulfillment
    @service.expects(:ssl_post).returns(FAILURE_RESPONSE)

    @options[:billing_address] = @address
    response = @service.fulfill('123456', @address, @line_items, @options)
    assert !response.success?
    assert response.test?
  end

  def test_stock_levels
    @service.expects(:ssl_get).returns(INVENTORY_RESPONSE)

    response = @service.fetch_all_stock_levels
    assert response.success?
    assert_equal 99, response.stock['AAA']
    assert_equal 9, response.stock['BBB']
  end

  def test_garbage_response
    @service.expects(:ssl_post).returns(GARBAGE_RESPONSE)

    @options[:billing_address] = @address
    response = @service.fulfill('123456', @address, @line_items, @options)
    assert !response.success?
  end

  private

  SUCCESSFUL_RESPONSE = '{"success": true, "valid": true, "test": true}'
  FAILURE_RESPONSE    = '{"success": false, "test": true}'
  INVENTORY_RESPONSE  = '{"success": true, "stock": {"AAA": 99, "BBB": 9}, "test": true}'
  GARBAGE_RESPONSE    = '<font face="Arial" size=2>/XML/shippingTest.asp</font><font face="Arial" size=2>, line 39</font>'
end
