require 'test_helper'

class ShipwireTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    
    @shipwire = ShipwireService.new(
                  :login => 'cody@example.com',
                  :password => 'test'
                )
    
    @options = { 
      :warehouse => '01',
      :shipping_method => 'UPS Ground'
    }
    
    @address = { 
      :name => 'Fred Brooks',
      :address1 => '1234 Penny Lane',
      :city => 'Jonsetown',
      :state => 'NC',
      :country => 'US',
      :zip => '23456',
      :email    => 'buyer@jadedpallet.com'
    }
    
    @line_items = [ { :sku => '9999', :quantity => 25 } ]
  end 
  
  def test_missing_login
    assert_raise(ArgumentError) do
      ShipwireService.new(:password => 'test')
    end
  end
  
  def test_missing_password
    assert_raise(ArgumentError) do
      ShipwireService.new(:login => 'cody')
    end
  end
  
  def test_missing_credentials
    assert_raise(ArgumentError) do
      ShipwireService.new(:password => 'test')
    end
  end
  
  def test_credentials_present
    assert_nothing_raised do
      ShipwireService.new(
        :login    => 'cody',
        :password => 'test'
      )
    end
  end
  
  def test_country_format
    xml = REXML::Document.new(@shipwire.send(:build_fulfillment_request, '123456', @address, @line_items, @options))
    country_node = REXML::XPath.first(xml, "//Country")
    assert_equal 'US', country_node.text
  end

  def test_stock_levels_dont_include_pending_by_default
    @shipwire.expects(:ssl_post).returns(xml_fixture('shipwire/inventory_get_response'))

    response = @shipwire.fetch_stock_levels
    assert response.success?
    assert_equal 926, response.stock_levels['BlackDog']
    assert_equal -1, response.stock_levels['MoustacheCat']
    assert_equal 677, response.stock_levels['KingMonkey']
  end

  def test_stock_levels_include_pending_when_set
    @shipwire = ShipwireService.new(
                  :login => 'cody@example.com',
                  :password => 'test',
                  :include_pending_stock => true
                )
    @shipwire.expects(:ssl_post).returns(xml_fixture('shipwire/inventory_get_response'))

    response = @shipwire.fetch_stock_levels
    assert response.success?
    assert @shipwire.include_pending_stock?
    assert_equal 926, response.stock_levels['BlackDog']
    assert_equal 805, response.stock_levels['MoustacheCat']
    assert_equal 921, response.stock_levels['KingMonkey']
  end

  def test_no_tracking_numbers_available
    @shipwire.expects(:ssl_post).returns(successful_empty_tracking_response)
    response = @shipwire.fetch_tracking_numbers(['1234'])
    assert response.success?
    assert_equal Hash.new, response.tracking_numbers
  end
  
  def test_successful_tracking
    expected = { "2986" => "1ZW682E90326614239",
                 "2987" => "1ZW682E90326795080" }
    
    @shipwire.expects(:ssl_post).returns(successful_tracking_response)
    response = @shipwire.fetch_tracking_numbers(["2986", "2987"])
    assert response.success?
    assert_equal "3", response.params["total_orders"]
    assert_equal "Test", response.params["status"]
    assert_equal "2", response.params["total_shipped_orders"]
    
    assert_equal expected, response.tracking_numbers
  end
  
  def test_successful_tracking_with_live_data
    @shipwire.expects(:ssl_post).returns(successful_live_tracking_response)
    response = @shipwire.fetch_tracking_numbers([
        '21',   '22',   '23',   '24',   '25',
        '26', '2581', '2576', '2593', '2598',
      '2610', '2611', '2613', '2616', '2631'
    ])
    assert response.success?
    assert_equal "15", response.params["total_orders"]
    assert_equal "0", response.params["status"]
    assert_equal "13", response.params["total_shipped_orders"]
    
    assert_equal 13, response.tracking_numbers.size
  end
  
  def test_valid_credentials
    @shipwire.expects(:ssl_post).returns(successful_empty_tracking_response)
    assert @shipwire.valid_credentials?
  end
  
  def test_invalid_credentials
    @shipwire.expects(:ssl_post).returns(invalid_login_response)
    assert !@shipwire.valid_credentials?
  end

  private
  def successful_empty_tracking_response
    "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\r\n<TrackingUpdateResponse><Status>Test</Status><TotalOrders></TotalOrders><TotalShippedOrders></TotalShippedOrders><TotalProducts></TotalProducts><Bookmark></Bookmark></TrackingUpdateResponse>"
  end
  
  def successful_tracking_response
    <<-XML
<?xml version="1.0"?>
<TrackingUpdateResponse>
  <Status>Test</Status>
  <Order id="2986" shipped="YES" shipper="UPS GD" handling="1.00" shipping="13.66" total="14.66">
    <TrackingNumber>1ZW682E90326614239</TrackingNumber>
  </Order>
  <Order id="2987" shipped="YES" shipper="UPS GD" handling="1.50" shipping="9.37" total="10.87">
    <TrackingNumber>1ZW682E90326795080</TrackingNumber>
  </Order>
  <Order id="2988" shipped="NO" shipper="UPS GD" handling="" shipping="" total="">
    <TrackingNumber></TrackingNumber>
  </Order>
  <TotalOrders>3</TotalOrders>
  <TotalShippedOrders>2</TotalShippedOrders>
  <Bookmark>2006-04-28 20:35:45</Bookmark>
</TrackingUpdateResponse>
    XML
  end
  
  def successful_live_tracking_response
    <<-XML
<?xml version="1.0" encoding="ISO-8859-1"?>
<TrackingUpdateResponse>
  <Status>0</Status>
  <Order id="21" shipped="YES" shipper="5" handling="0.00" shipping="6.58" total="6.58">
    <TrackingNumber>1Z6296VW0398500001</TrackingNumber>
  </Order>
  <Order id="22" shipped="YES" shipper="5" handling="0.00" shipping="8.13" total="8.13">
    <TrackingNumber>1Z6296VW0390790002</TrackingNumber>
  </Order>
  <Order id="23" shipped="YES" shipper="5" handling="0.00" shipping="7.63" total="7.63">
    <TrackingNumber>1Z6296VW0396490003</TrackingNumber>
  </Order>
  <Order id="24" shipped="YES" shipper="5" handling="0.00" shipping="8.97" total="8.97">
    <TrackingNumber>1Z6296VW0390200004</TrackingNumber>
  </Order>
  <Order id="25" shipped="YES" shipper="5" handling="0.00" shipping="8.42" total="8.42">
    <TrackingNumber>1Z6296VW0393240005</TrackingNumber>
  </Order>
  <Order id="26" shipped="YES" shipper="5" handling="0.00" shipping="8.42" total="8.42">
    <TrackingNumber>1Z6296VW0396400006</TrackingNumber>
  </Order>
  <Order id="2581" shipped="YES" shipper="5" handling="0.00" shipping="8.21" total="8.21">
    <TrackingNumber>1Z6296VW0391160007</TrackingNumber>
  </Order>
  <Order id="2576" shipped="YES" shipper="43" handling="0.00" shipping="18.60" total="18.60">
    <TrackingNumber>CJ3026000018US</TrackingNumber>
  </Order>
  <Order id="2593" shipped="YES" shipper="5" handling="0.00" shipping="7.63" total="7.63">
    <TrackingNumber>1Z6296VW0398660008</TrackingNumber>
  </Order>
  <Order id="2598" shipped="YES" shipper="5" handling="0.00" shipping="9.84" total="9.84">
    <TrackingNumber>1Z6296VW0391610009</TrackingNumber>
  </Order>
  <Order id="2610" shipped="YES" shipper="5" handling="0.00" shipping="7.63" total="7.63">
    <TrackingNumber>1Z6296VW0395650010</TrackingNumber>
  </Order>
  <Order id="2611" shipped="YES" shipper="5" handling="0.00" shipping="7.13" total="7.13">
    <TrackingNumber>1Z6296VW0397050011</TrackingNumber>
  </Order>
  <Order id="2613" shipped="YES" shipper="5" handling="0.00" shipping="8.97" total="8.97">
    <TrackingNumber>1Z6296VW0398970012</TrackingNumber>
  </Order>
  <Order id="2616" shipped="NO" shipper="5" handling="0.00" shipping="9.84" total="9.84">
    <TrackingNumber></TrackingNumber>
  </Order>
  <Order id="2631" shipped="NO" shipper="" handling="" shipping="" total="">
    <TrackingNumber></TrackingNumber>
  </Order>
  <TotalOrders>15</TotalOrders>
  <TotalShippedOrders>13</TotalShippedOrders>
  <TotalProducts/>
  <Bookmark/>
</TrackingUpdateResponse>

    XML
  end
  
  def invalid_login_response
    <<-XML
<?xml version="1.0" encoding="ISO-8859-1"?>
<TrackingUpdateResponse><Status>Error</Status><ErrorMessage>
Error with EmailAddress, valid email is required.
    There is an error in XML document.
</ErrorMessage></TrackingUpdateResponse>    
    XML
  end
end
