require File.dirname(__FILE__) + '/../test_helper'

class BaseTest < Test::Unit::TestCase
  include ActiveMerchant::Fulfillment

  def test_get_shipwire_by_string
    assert_equal ShipwireService, Base.service('shipwire')
  end

  def test_get_shipwire_by_name
    assert_equal ShipwireService, Base.service(:shipwire)
  end
  
  def test_get_unknown_service
    assert_raise(NameError){ Base.service(:polar_north) }
  end
end
