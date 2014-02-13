require 'test_helper'

class RemoteWebgistixTest < ActiveMerchant::Fulfillment::Test
  def setup
    Base.mode = :test

    @service = WebgistixService.new( fixtures(:webgistix) )

    @options = {
      :shipping_method => 'Ground',
      :email    => 'buyer@jadedpallet.com'
    }

    @address = { :name => 'Fred Brooks',
                 :address1 => '1234 Penny Lane',
                 :city => 'Jonsetown',
                 :state => 'NC',
                 :country => 'US',
                 :zip => '23456'
               }

    @line_items = [
      { :sku => 'WX-01-4001',
        :quantity => 2
      }
    ]

  end

  def test_successful_order_submission
    response = @service.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
    assert_equal WebgistixService::SUCCESS_MESSAGE, response.message
  end

  def test_order_multiple_line_items
    @line_items.push(
      { :sku => 'WX-01-1020',
        :quantity => 3
       }
    )

    response = @service.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
    assert_equal WebgistixService::SUCCESS_MESSAGE, response.message
  end

  def test_invalid_sku_during_fulfillment
    line_items = [ { :sku => 'invalid', :quantity => 1 } ]
    response = @service.fulfill('123456', @address, line_items, @options)
    assert !response.success?
    assert response.test?
    assert_equal WebgistixService::FAILURE_MESSAGE, response.message
  end

  def test_invalid_credentials_during_fulfillment
    service = WebgistixService.new(
      :login => 'your@email.com',
      :password => 'password')

    response = service.fulfill('123456', @address, @line_items, @options)
    assert !response.success?
    assert response.test?
    assert_equal "Invalid Credentials", response.message
  end

  def test_get_inventory
    response = @service.fetch_stock_levels
    assert response.success?
    assert response.test?
    assert_equal 90,  response.stock_levels['WX-01-3022']
    assert_equal 140, response.stock_levels['WX-04-1080']
  end

  def test_fetch_tracking_data
    response = @service.fetch_tracking_data([
      '1254658', 'FAItest123', 'Flat Rate Test Order 4'
    ])
    assert response.success?
    assert_equal ['4209073191018052136352154'], response.tracking_numbers['1254658']
    assert_equal ['UPS'], response.tracking_companies['1254658']
  end

  def test_fetch_tracking_numbers
    response = @service.fetch_tracking_numbers([
      '1254658', 'FAItest123', 'Flat Rate Test Order 4'
    ])
    assert response.success?
    assert_equal ['4209073191018052136352154'], response.tracking_numbers['1254658']
    assert_equal ['9101805213907472080032'],    response.tracking_numbers['Flat Rate Test Order 4']
    assert_nil response.tracking_numbers['FAItest123'] # 'Not Shipped'
  end

  def test_valid_credentials
    assert @service.valid_credentials?
  end

  def test_invalid_credentials
    service = WebgistixService.new(
      :login => 'your@email.com',
      :password => 'password')

    assert !service.valid_credentials?
  end
end
