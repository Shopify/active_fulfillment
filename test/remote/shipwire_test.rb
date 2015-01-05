require 'test_helper'

class RemoteShipwireTest < Minitest::Test
  include ActiveFulfillment::Test::Fixtures

  def setup
    ActiveFulfillment::Base.mode = :test

    @shipwire = ActiveFulfillment::ShipwireService.new(fixtures(:shipwire))

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
    shipwire = ActiveFulfillment::ShipwireService.new(
      :login => 'your@email.com',
      :password => 'password')

    assert_raises(ActiveUtils::ResponseError, 'Failed with 401 Authorization Required') do
      shipwire.fulfill(SecureRandom.uuid, @us_address, @line_items, @options)
    end
  end

  def test_successful_order_submission_to_us
    response = @shipwire.fulfill(SecureRandom.uuid, @us_address, @line_items, @options)
    assert response.success?
    assert response.test?
    assert response.params['transaction_id']
    assert_equal '1', response.params['total_orders']
    assert_equal '1', response.params['total_items']
    assert_equal '0', response.params['status']
    assert_equal 'Successfully submitted the order', response.message
  end

  def test_successful_order_submission_to_uk
    response = @shipwire.fulfill(SecureRandom.uuid, @uk_address, @line_items, @options)
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

    response = @shipwire.fulfill(SecureRandom.uuid, @us_address, @line_items, @options)
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

    response = @shipwire.fulfill(SecureRandom.uuid, @us_address, line_items, options)

    assert response.success?
    assert response.test?
    refute response.params['transaction_id'].blank?
    assert_equal "1", response.params['total_orders']
    assert_equal "1", response.params['total_items']
    assert_equal "0", response.params['status']
    assert_equal 'Successfully submitted the order', response.message
  end

  def test_invalid_credentials_during_inventory
    shipwire = ActiveFulfillment::ShipwireService.new(
                 :login => 'your@email.com',
                 :password => 'password'
               )

    response = shipwire.fetch_stock_levels

    refute response.success?
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

  def test_fetch_tracking_data
    response = @shipwire.fetch_tracking_data(['123456'])
    assert response.success?
    assert response.test?
    assert_instance_of Hash, response.tracking_numbers # {"40298"=>["9400110200793596422990"]}
    assert_instance_of Hash, response.tracking_companies # {"40298"=>["USPS"]}
  end

  def test_fetch_tracking_numbers
    response = @shipwire.fetch_tracking_numbers(['123456'])
    assert response.success?
    assert response.test?
    assert_instance_of Hash, response.tracking_numbers # {"40298"=>["9400110200793596422990"]}
  end

  def test_valid_credentials
    assert @shipwire.valid_credentials?
  end

  def test_invalid_credentials
    service = ActiveFulfillment::ShipwireService.new(
                :login => 'your@email.com',
                :password => 'password'
              )
    refute service.valid_credentials?
  end
end
