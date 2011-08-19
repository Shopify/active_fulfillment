require 'test_helper'

class RemoteAmazonTest < Test::Unit::TestCase
  # In order for these tests to work you must have a live account with Amazon.
  # You can sign up at http://amazonservices.com/fulfillment/
  # The SKUs must also exist in your inventory. You do not want the SKUs you
  # use for testing to actually have inventory in the Amazon warehouse, or else
  # the shipments will actually be fulfillable
  def setup
    @service = AmazonService.new( fixtures(:amazon) )

    @options = { 
      :shipping_method => 'Standard',
      :order_date => Time.now.utc.yesterday,
      :comment => "Delayed due to tornados"
     }
     
     @address = { :name => 'Johnny Chase',
                  :address1 => '100 Information Super Highway',
                  :address2 => 'Suite 66',
                  :city => 'Beverly Hills',
                  :state => 'CA',
                  :country => 'US',
                  :zip => '90210'
                }
     
     @line_items = [
       { :sku => 'SETTLERS8',
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
    @line_items.push(
      { :sku => 'CARCASSONNE',
        :quantity => 2
       }
    )
    
    response = @service.fulfill(ActiveMerchant::Utils.generate_unique_id, @address, @line_items, @options)
    assert response.success?
  end
  
  def test_invalid_credentials_during_fulfillment
    service = AmazonService.new(
      :login => 'y',
      :password => 'p')
    
    response = service.fulfill(ActiveMerchant::Utils.generate_unique_id, @address, @line_items, @options)
    assert !response.success?
    assert_equal "aws:Client.InvalidClientTokenId The AWS Access Key Id you provided does not exist in our records.", response.message
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
    response = @service.fetch_stock_levels(:start_time => 1.year.ago)
    assert response.success?
    assert_equal 0, response.stock_levels['SETTLERS']
  end
  
  def test_fetch_tracking_numbers
    response = @service.fetch_tracking_numbers(['123456']) # an actual order
    assert response.success?
    assert_equal Hash.new, response.tracking_numbers # no tracking numbers in testing
  end
  
  def test_fetch_tracking_numbers_ignores_not_found
    response = @service.fetch_tracking_numbers(['#1337-1'])
    assert response.success?
    assert_equal Hash.new, response.tracking_numbers
  end
  
  def test_valid_credentials
    assert @service.valid_credentials?
  end
  
  def test_invalid_credentials
    service = AmazonService.new(
      :login => 'your@email.com',
      :password => 'password')
    assert !service.valid_credentials?
  end
  
  def test_get_status_fails
    service = AmazonService.new(
      :login => 'your@email.com',
      :password => 'password')
    response = service.status
    assert !response.success?
    assert_equal "aws:Client.InvalidClientTokenId The AWS Access Key Id you provided does not exist in our records.", response.message
  end
  
  def test_get_status
    service = AmazonService.new(fixtures(:amazon))
    response = service.status
    assert response.success?
  end
  
end
