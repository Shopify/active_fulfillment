require 'test_helper'

class ShipwireTest < Minitest::Test
  include ActiveFulfillment::Test::Fixtures

  PASSWORD = 'test_password'

  def setup
    ActiveFulfillment::Base.mode = :test

    @shipwire = ActiveFulfillment::ShipwireService.new(
                  :login => 'cody@example.com',
                  :password => PASSWORD
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
      :company => 'MyCorp',
      :email    => 'buyer@jadedpallet.com'
    }

    @line_items = [ { :sku => '9999', :quantity => 25 } ]
  end

  def test_missing_login
    assert_raises(ArgumentError) do
      ActiveFulfillment::ShipwireService.new(:password => PASSWORD)
    end
  end

  def test_missing_password
    assert_raises(ArgumentError) do
      ActiveFulfillment::ShipwireService.new(:login => 'cody')
    end
  end

  def test_missing_credentials
    assert_raises(ArgumentError) do
      ActiveFulfillment::ShipwireService.new(:password => PASSWORD)
    end
  end

  def test_credentials_present
    assert ActiveFulfillment::ShipwireService.new(
      :login    => 'cody',
      :password => PASSWORD
    )
  end

  def test_country_format
    xml = Nokogiri::XML(@shipwire.send(:build_fulfillment_request, '123456', @address, @line_items, @options))
    country_node = xml.at_xpath(xml, "//Country")
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

  def test_stock_levels_parses_invalid_credentials
    @shipwire.expects(:ssl_post).returns(xml_fixture('shipwire/invalid_login_inventory_update_response'))

    response = @shipwire.fetch_stock_levels
    refute response.success?
    assert_equal 'Error with Valid Username/EmailAddress and Password Required. There is an error in XML document.', response.message
  end

  def test_stock_levels_logs_request_and_response
    @shipwire.class.logger.expects(:info).with do |message|
      assert_match /InventoryUpdate/, message unless message.include?('InventoryUpdateResponse')
      refute message.include?(PASSWORD)
      true
    end.twice

    @shipwire.expects(:ssl_post).returns(xml_fixture('shipwire/inventory_get_response'))
    response = @shipwire.fetch_stock_levels
  end

  def test_logging_with_specific_passwords
    @shipwire = ActiveFulfillment::ShipwireService.new(login: 'cody@example.com', password: 345)
    @shipwire.class.logger.expects(:info).with do |message|
      refute message.include?('345')
      true
    end.twice

    @shipwire.stubs(:ssl_post).returns(xml_fixture('shipwire/inventory_get_response'))
    response = @shipwire.fetch_stock_levels
  end

  def test_stock_levels_include_pending_when_set
    @shipwire = ActiveFulfillment::ShipwireService.new(
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

  def test_inventory_request_with_include_empty_tag
     @shipwire = ActiveFulfillment::ShipwireService.new(
                  :login => 'cody@example.com',
                  :password => 'test',
                  :include_empty_stock => true
                )
    xml = Nokogiri::XML(@shipwire.send(:build_inventory_request, {}))
    assert xml.at_xpath(xml, '//IncludeEmpty')
  end

  def test_no_tracking_numbers_available
    successful_empty_tracking_response = xml_fixture('shipwire/successful_empty_tracking_response')
    @shipwire.expects(:ssl_post).returns(successful_empty_tracking_response)
    response = @shipwire.fetch_tracking_numbers(['1234'])
    assert response.success?
    assert_equal Hash.new, response.tracking_numbers
  end

  def test_successful_tracking
    expected = { "2986" => ["1ZW682E90326614239"],
                 "2987" => ["1ZW682E90326795080"] }

    successful_tracking_response = xml_fixture('shipwire/successful_tracking_response')
    @shipwire.expects(:ssl_post).returns(successful_tracking_response)
    response = @shipwire.fetch_tracking_numbers(["2986", "2987"])
    assert response.success?
    assert_equal "3", response.params["total_orders"]
    assert_equal "Test", response.params["status"]
    assert_equal "2", response.params["total_shipped_orders"]

    assert_equal expected, response.tracking_numbers
  end

  def test_successful_tracking_with_live_data
    successful_live_tracking_response = xml_fixture('shipwire/successful_live_tracking_response')
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

  def test_successful_tracking_with_urls
    successful_tracking_response_with_urls = xml_fixture('shipwire/successful_tracking_response_with_tracking_urls')
    @shipwire.expects(:ssl_post).returns(successful_tracking_response_with_urls)
    response = @shipwire.fetch_tracking_data(["40289"])
    assert response.success?
    assert_equal "1", response.params["total_orders"]
    assert_equal "Test", response.params["status"]
    assert_equal "1", response.params["total_shipped_orders"]

    assert_equal ["9400110200793596422990"], response.tracking_numbers["40298"]
    assert_equal ["USPS"], response.tracking_companies["40298"]
    assert_equal ["http://trkcnfrm1.smi.usps.com/PTSInternetWeb/InterLabelInquiry.do?origTrackNum=9400110200793596422990"], response.tracking_urls["40298"]
  end

  def test_valid_credentials
    successful_empty_tracing_response = xml_fixture('shipwire/successful_empty_tracking_response')
    @shipwire.expects(:ssl_post).returns(successful_empty_tracing_response)
    assert @shipwire.valid_credentials?
  end

  def test_invalid_credentials
    invalid_login_response = xml_fixture('shipwire/invalid_login_response')
    @shipwire.expects(:ssl_post).returns(invalid_login_response)
    assert !@shipwire.valid_credentials?
  end

  def test_affiliate_id
    ActiveFulfillment::ShipwireService.affiliate_id = 'affiliate_id'
    xml = Nokogiri::XML(@shipwire.send(:build_fulfillment_request, '123456', @address, @line_items, @options))
    affiliate_id = xml.at_xpath(xml, "//AffiliateId")
    assert_equal 'affiliate_id', affiliate_id.text
  end

  def test_company_name_in_request
    xml = Nokogiri::XML(@shipwire.send(:build_fulfillment_request, '123456', @address, @line_items, @options))
    company_node = xml.at_xpath(xml, "//Company")
    assert_equal 'MyCorp', company_node.text
  end

  def test_order_excludes_note_by_default
    xml = Nokogiri::XML(@shipwire.send(:build_fulfillment_request, '123456', @address, @line_items, @options))
    note_node = xml.at_xpath(xml, "//Note")
    assert_equal 0, note_node.children.select { |child| child.cdata? }.size
    assert_equal false, note_node.cdata?
  end

  def test_order_includes_note_when_present
    @options[:note] = "A test note"
    xml = Nokogiri::XML(@shipwire.send(:build_fulfillment_request, '123456', @address, @line_items, @options))
    note_node = xml.at_xpath(xml, "//Note")
    assert_equal "A test note", note_node.text.strip
    assert_equal note_node.children.select { |child| child.cdata? }.size, 1
  end

  def test_error_response_cdata_parsing
    @shipwire.expects(:ssl_post).returns(xml_fixture('shipwire/fulfillment_failure_response'))
    assert !@shipwire.valid_credentials?
  end

end
