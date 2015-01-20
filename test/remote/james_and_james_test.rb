require 'test_helper'

class RemoteJamesAndJamesTest < Minitest::Test
  include ActiveFulfillment::Test::Fixtures

  def setup
    ActiveFulfillment::Base.mode = :test

    @service = ActiveFulfillment::JamesAndJamesService.new(fixtures(:james_and_james))

    @options = {
      shipping_method: 'Ground',
      email:    'buyer@jadedpallet.com'
    }

    @address = {
      name: 'Fred Brooks',
      address1: '1234 Penny Lane',
      city: 'Jonsetown',
      state: 'NC',
      country: 'US',
      zip: '23456'
    }

    @line_items = [
      {
        sku: 'SBLK8',
        quantity: 2,
        price: 10
      }
    ]

  end

  def test_successful_order_submission
    @options[:billing_address] = @address
    response = @service.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
  end

  def test_order_multiple_line_items
    @line_items.push({
      sku: 'SWHT8',
      quantity: 3,
      price: 10
    })
    @options[:billing_address] = @address
    response = @service.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
  end

  def test_invalid_sku_during_fulfillment
    line_items = [{sku: 'invalid', quantity: 1}]
    @options[:billing_address] = @address
    response = @service.fulfill('123456', @address, line_items, @options)
    assert !response.success?
    assert response.test?
  end

  def test_invalid_credentials_during_fulfillment
    service = ActiveFulfillment::JamesAndJamesService.new(subdomain: 'test', key: 'test')
    @options[:billing_address] = @address
    response = service.fulfill('123456', @address, @line_items, @options)
    refute response.success?
    assert_equal "Not Found", response.message
  end

  def test_get_inventory
    response = @service.fetch_all_stock_levels
    assert response.success?
    assert response.test?
    assert_equal 99,  response.stock['SBLK8']
  end

end
