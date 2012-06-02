require 'test_helper'

class RemoteAmazonMarketplaceWebservicesTest < Test::Unit::TestCase

  def setup
    @service = AmazonMarketplaceWebService.new( fixtures(:amazon_mws) )

    @options = {
      :shipping_method => 'Standard',
      :order_date => Time.now.utc.yesterday,
      :comment => "Delayed due to tornadoes"
    }

    @address = {
      :name => 'Johnny Chase',
      :address1 => '100 Information Super Highway',
      :address2 => 'Suite 66',
      :city => 'Beverly Hills',
      :state => 'CA',
      :country => 'US',
      :zip => '90210'
    }
    
    @line_items = [
                   { :sku => 'SETTLERS',
                     :quantity => 1 #,
                     #:comment => 'Awesome'
                   }
                  ]
  end

  def test_successful_order_submission
    response = @service.fulfill(ActiveMerchant::Utils.generate_unique_id, @address, @line_items, @options)
    assert response.success?
    assert !response.test?
  end

  def test_order_multiple_line_items
    @line_items.push({
                       :sku => 'CARCASSONNE',
                       :quantity => 2
                     })

    response = @service.fulfill(ActiveMerchant::Utils.generate_unique_id, @address, @line_items, @options)
    assert response.success?
  end

  def test_invalid_credentials_during_fulfillment
    service = AmazonMarketplaceWebService.new(
      :login => 'y',
      :password => 'p',
      :seller_id => 'o')
    
    response = service.fulfill(ActiveMerchant::Utils.generate_unique_id, @address, @line_items, @options)
    assert !response.success?
    
    assert_equal "InvalidAccessKeyId: The AWS Access Key Id you provided does not exist in our records.", response.response_comment
  end
  
  def test_list_orders
    response = @service.fetch_current_orders
    assert response.success?
  end

  def test_get_inventory
    response = @service.fetch_stock_levels(:sku => '2R-JAXZ-P0IB')
    assert response.success?
    assert_equal 0, response.stock_levels['2R-JAXZ-P0IB']
  end

  def test_list_inventory
    response = @service.fetch_stock_levels(:start_time => Time.parse('2010-01-01'))
    assert response.success?
    assert_equal 0, response.stock_levels['SETTLERS']
  end
  
  def test_fetch_tracking_numbers
    response = @service.fetch_tracking_numbers(['123456']) # an actual order
    assert response.success?
    assert_equal Hash.new, response.tracking_numbers # no tracking numbers in testing
  end
  
  def test_fetch_tracking_numbers_ignores_not_found
    response = @service.fetch_tracking_numbers(['1337-1'])
    assert response.success?
    assert_equal Hash.new, response.tracking_numbers
  end
  
  def test_valid_credentials
    assert @service.valid_credentials?
  end
  
  def test_invalid_credentials
    service = AmazonMarketplaceWebService.new(
      :login => 'your@email.com',
      :password => 'password',
      :seller_id => 'SellerNumber1')
    assert !service.valid_credentials?
  end
  
  def test_get_status_does_not_require_valid_credentials
    service = AmazonMarketplaceWebService.new(
      :login => 'your@email.com',
      :password => 'password')
    response = service.status
    assert response.success?
  end
  
  def test_get_status
    service = AmazonMarketplaceWebService.new(fixtures(:amazon))
    response = service.status
    assert response.success?
  end
end
