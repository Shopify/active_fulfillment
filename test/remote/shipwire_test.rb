require 'test_helper'

class RemoteShipwireTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @shipwire = ShipwireService.new( fixtures(:shipwire) )
    
    @options = { 
      :warehouse => 'LAX',
      :shipping_method => 'UPS Ground',
      :email => 'cody@example.com'
    }
    
    @us_address = { 
      :name     => 'Steve Jobs',
      :company  => 'Apple Computer Inc.',
      :address1 => '1 Infinite Loop',
      :city     => 'Cupertino',
      :state    => 'CA',
      :country  => 'US',
      :zip      => '95014',
      :email    => 'steve@apple.com'
    }
    
    @uk_address = { 
      :name     => 'Bob Diamond',
      :company  => 'Barclays Bank PLC',
      :address1 => '1 Churchill Place',
      :city     => 'London',
      :country  => 'GB',
      :zip      => 'E14 5HP',
      :email    => 'bob@barclays.co.uk'
    }
    
    @line_items = [ { :sku => 'AF0001', :quantity => 25 } ]
  end
  
  def test_invalid_credentials_during_fulfillment
    shipwire = ShipwireService.new(
      :login => 'your@email.com',
      :password => 'password')
      
    response = shipwire.fulfill('123456', @us_address, @line_items, @options)
    assert !response.success?
    assert response.test?
    assert_equal 'Error', response.params['status']
    assert_equal "Could not verify e-mail/password combination", response.message
  end
  
  def test_successful_order_submission_to_us
    response = @shipwire.fulfill('123456', @us_address, @line_items, @options)
    assert response.success?
    assert response.test?
    assert response.params['transaction_id']
    assert_equal '1', response.params['total_orders']
    assert_equal '1', response.params['total_items']
    assert_equal '0', response.params['status']
    assert_equal 'Successfully submitted the order', response.message
  end
  
  def test_successful_order_submission_to_uk
    response = @shipwire.fulfill('123456', @uk_address, @line_items, @options)
    assert response.success?
    assert response.test?
    assert response.params['transaction_id']
    assert_equal '1', response.params['total_orders']
    assert_equal '1', response.params['total_items']
    assert_equal '0', response.params['status']
    assert_equal 'Successfully submitted the order', response.message
  end
  
  def test_order_multiple_line_items
    @line_items.push({ :sku => 'AF0002', :quantity => 25 })
    
    response = @shipwire.fulfill('123456', @us_address, @line_items, @options)
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
    
    line_items = [ { :quantity => 1, :description => 'Libtech Snowboard' } ]
    
    response = @shipwire.fulfill('123456', @us_address, line_items, options)
    
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
                 :password => 'password'
               )
      
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
  
  def test_fetch_tracking_numbers
    response = @shipwire.fetch_tracking_numbers
    assert response.success?    
    assert response.test?
    assert_equal Hash.new, response.tracking_numbers
  end
  
  def test_valid_credentials
    assert @shipwire.valid_credentials?
  end
  
  def test_invalid_credentials
    service = ShipwireService.new(
                :login => 'your@email.com',
                :password => 'password'
              )
    assert !service.valid_credentials?
  end
end