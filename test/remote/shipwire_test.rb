require File.dirname(__FILE__) + '/../test_helper'

class RemoteShipwireTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @shipwire = ShipwireService.new( fixtures(:shipwire) )
    
    @options = { 
      :warehouse => '01',
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
        :quantity => 25,
        :description => 'Libtech Snowboard',
        :length => 3,
        :width => 2,
        :height => 1,
        :weight => 2,
        :declared_value => 1.25
      }
    ]
  end
  
  def test_invalid_credentials_during_fulfillment
    shipwire = ShipwireService.new(
      :login => 'your@email.com',
      :password => 'password')
      
    response = shipwire.fulfill('123456', @address, @line_items, @options)
    assert !response.success?
    assert response.test?
    assert_equal 'Error', response.params['status']
    assert_equal "Could not verify e-mail/password combination", response.message
  end
  
  def test_successful_order_submission
    response = @shipwire.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
    assert response.params['transaction_id']
    assert_equal '1', response.params['total_orders']
    assert_equal '1', response.params['total_items']
    assert_equal '0', response.params['status']
    assert_equal 'Successfully submitted the order', response.message
  end
  
  def test_order_multiple_line_items
    @line_items.push(
      { :sku => '9998',
        :quantity => 25,
        :description => 'Libtech Snowboard',
        :length => 3,
        :width => 2,
        :height => 1,
        :weight => 2,
        :value => 1.25
       }
    )
    
    response = @shipwire.fulfill('123456', @address, @line_items, @options)
    assert response.success?
    assert response.test?
    assert response.params['transaction_id']
    assert_equal '1', response.params['total_orders']
    assert_equal '2', response.params['total_items']
    assert_equal '0', response.params['status']
    assert_equal 'Successfully submitted the order', response.message  
  end
  
  def test_no_sku_is_sent_with_fulfillment
      options = { 
        :shipping_method => 'UPS Ground'
      }
    
    line_items = [
      { :quantity => 1,
        :description => 'Libtech Snowboard'
      }
    ]
    
    response = @shipwire.fulfill('123456', @address, line_items, options)
    
    assert response.success?
    assert response.test?
    assert_not_nil response.params['transaction_id']
    assert_equal "1", response.params['total_orders']
    assert_equal "0", response.params['total_items']
    assert_equal "0", response.params['status']
    assert_equal 'Successfully submitted the order', response.message  
  end
  
  def test_invalid_credentials_during_inventory
    shipwire = ShipwireService.new(
      :login => 'your@email.com',
      :password => 'password')
      
    response = shipwire.fetch_stock_levels
    assert !response.success?
    assert response.test?
    assert_equal 'Error', response.params['status']
    assert_equal "Error with EmailAddress, valid email is required. There is an error in XML document.", response.message
  end
  
  def test_get_inventory
    response = @shipwire.fetch_stock_levels
    assert response.success?
    assert response.test?
    assert_equal 14, response.stock_levels["GD802-024"]
    assert_equal 32, response.stock_levels["GD201-500"]
    assert_equal "2", response.params["total_products"]
  end
end