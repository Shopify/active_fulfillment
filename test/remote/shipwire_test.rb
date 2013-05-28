require 'test_helper'

class RemoteShipwireTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @shipwire = ShipwireService.new( fixtures(:shipwire) )
    @tracking = <<-XML
    <TrackingUpdateResponse>
    <Status>0</Status>
    <Order id="40298" shipwireId="1234567890-1234567-1" warehouse="Chicago" shipped="NO" shipper="" shipDate="2011-03-14 11:11:40" delivered="YES" expectedDeliveryDate="2011-03-22 00:00:00" returned="NO" href="https://app.shipwire.com/c/t/xxx1:yyy1" affiliateStatus="canceled" manuallyEdited="NO"/>
    <Order id="40298" shipwireId="1234567890-1234568-1" warehouse="Philadelphia" shipped="YES" shipper="USPS FC" shipperFullName="USPS First-Class Mail Parcel + Delivery Confirmation" shipDate="2011-03-15 10:40:06" expectedDeliveryDate="2011-03-22 00:00:00" handling="0.00" shipping="4.47" packaging="0.00" total="4.47" returned="YES" returnDate="2011-05-04 17:33:25" returnCondition="GOOD" href="https://app.shipwire.com/c/t/xxx1:yyy2" affiliateStatus="shipwireFulfilled" manuallyEdited="NO">
    <TrackingNumber carrier="USPS" delivered="YES" deliveryDate="2011-03-21 17:10:00" href="http://trkcnfrm1.smi.usps.com/PTSInternetWeb/InterLabelInquiry.do?origTrackNum=9400110200793472606087">9400110200793472606087</TrackingNumber>
    </Order>
    <Order id="40299" shipwireId="1234567890-1234569-1" warehouse="Chicago" shipped="YES" shipper="USPS FC" shipperFullName="USPS First-Class Mail Parcel + Delivery Confirmation" shipDate="2011-04-08 09:33:10" delivered="NO" expectedDeliveryDate="2011-04-15 00:00:00" handling="0.00" shipping="4.47" packaging="0.00" total="4.47" returned="NO" href="https://app.shipwire.com/c/t/xxx1:yyy3" affiliateStatus="shipwireFulfilled" manuallyEdited="NO">
    <TrackingNumber carrier="USPS" delivered="NO" href="http://trkcnfrm1.smi.usps.com/PTSInternetWeb/InterLabelInquiry.do?origTrackNum=9400110200793596422990">9400110200793596422990</TrackingNumber>
    </Order>
    <TotalOrders>3</TotalOrders>
    <TotalShippedOrders>2</TotalShippedOrders>
    <TotalProducts>8</TotalProducts>
    <Bookmark>2011-10-22 14:13:16</Bookmark>
    <ProcessingTime units="ms">19</ProcessingTime>
    </TrackingUpdateResponse>
    XML
    
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
    assert_equal "Could not verify Username/EmailAddress and Password combination", response.message
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
    assert_equal "Error with Valid Username/EmailAddress and Password Required. There is an error in XML document.", response.message
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
    response = @shipwire.fetch_tracking_numbers(['123456'])
    assert response.success?    
    assert response.test?
    assert_equal Hash.new, response.tracking_numbers # no tracking numbers in testing
  end

  def test_reads_tracking_url
    response = @shipwire.parse_tracking_response(@tracking)
    puts "#{response.inspect}"
    assert response.success?    
    assert response.test?
    assert_equal '9400110200793472606087', response.tracking_numbers # no tracking numbers in testing
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
