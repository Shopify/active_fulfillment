require File.dirname(__FILE__) + '/../../test_helper'

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
    assert_equal 'US United States', country_node.text
  end
  
  def test_england_country_format
    @address[:country] = 'GB'
    
    xml = REXML::Document.new(@shipwire.send(:build_fulfillment_request, '123456', @address, @line_items, @options))
    country_node = REXML::XPath.first(xml, "//Country")
    assert_equal 'UK United Kingdom', country_node.text
  end
  
  def test_no_tracking_numbers_available
    @shipwire.expects(:ssl_post).returns(successful_empty_tracking_response)
    response = @shipwire.fetch_tracking_numbers
    assert response.success?
    assert_equal Hash.new, response.tracking_numbers
    
  end
  
  def test_successful_tracking
    expected = { "2986" => "1ZW682E90326614239",
                 "2987" => "1ZW682E90326795080" }
    
    @shipwire.expects(:ssl_post).returns(successful_tracking_response)
    response = @shipwire.fetch_tracking_numbers
    assert response.success?
    assert_equal "3", response.params["total_orders"]
    assert_equal "Test", response.params["status"]
    assert_equal "2", response.params["total_shipped_orders"]
    
    assert_equal expected, response.tracking_numbers
    
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
  <Order id="2986" shipped="YES" trackingNumber="1ZW682E90326614239" shipper="UPS GD" handling="1.00" shipping="13.66" total="14.66"/>
  <Order id="2987" shipped="YES" trackingNumber="1ZW682E90326795080" shipper="UPS GD" handling="1.50" shipping="9.37" total="10.87"/>
  <Order id="2988" shipped="NO" trackingNumber="" shipper="UPS GD" handling="" shipping="" total=""/>
  <TotalOrders>3</TotalOrders>
  <TotalShippedOrders>2</TotalShippedOrders>
  <Bookmark>2006-04-28 20:35:45</Bookmark>
</TrackingUpdateResponse>
    XML
  end
end
