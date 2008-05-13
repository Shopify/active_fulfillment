require File.dirname(__FILE__) + '/../test_helper'

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
    response = @service.fulfill(generate_order_id, @address, @line_items, @options)
    assert response.success?
    assert !response.test?
  end
  
  def test_order_multiple_line_items
    @line_items.push(
      { :sku => 'CARCASSONNE',
        :quantity => 2
       }
    )
    
    response = @service.fulfill(generate_order_id, @address, @line_items, @options)
    assert response.success?
  end
  
  def test_invalid_credentials_during_fulfillment
    service = AmazonService.new(
      :login => 'y',
      :password => 'p')
    
    response = service.fulfill(generate_order_id, @address, @line_items, @options)
    assert !response.success?
    assert_equal "AWS was not able to validate the provided access credentials.", response.message
  end
end