require 'test_helper'

class BaseTest < ActiveMerchant::Fulfillment::Test
  include ActiveMerchant::Fulfillment

  def test_get_shipwire_by_string
    assert_equal ShipwireService, Base.service('shipwire')
  end

  def test_get_shipwire_by_name
    assert_equal ShipwireService, Base.service(:shipwire)
  end
  
  def test_get_unknown_service
    assert_raises(NameError){ Base.service(:polar_north) }
  end
end
