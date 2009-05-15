require File.dirname(__FILE__) + '/../test_helper'

class RemoteWebgistixTest < Test::Unit::TestCase
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
    assert_equal "Access Denied", response.message
  end
end