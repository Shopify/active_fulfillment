require File.dirname(__FILE__) + '/../../test_helper'

class ShipwireTest < Test::Unit::TestCase
  def setup
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
end
