require 'test_helper'

class ShopifyAPITest < Test::Unit::TestCase

  def setup
    @service = build_service()
  end

  def test_request_uri_is_correct_when_no_sku_passed
    Timecop.freeze do
      timestamp = Time.now.utc.to_i
      uri = @service.send(:request_uri, 'fetch_stock', {timestamp: timestamp, shop: 'www.snowdevil.ca'})
      assert_equal "http://supershopifyapptwin.com/fetch_stock.json?shop=www.snowdevil.ca&timestamp=#{timestamp}", uri.to_s
    end
  end

  def test_request_uri_is_correct_when_sku_is_passed
    Timecop.freeze do
      timestamp = Time.now.utc.to_i
      uri = @service.send(:request_uri, 'fetch_stock', {sku: '123', timestamp: timestamp, shop: 'www.snowdevil.ca'})
      assert_equal "http://supershopifyapptwin.com/fetch_stock.json?shop=www.snowdevil.ca&sku=123&timestamp=#{timestamp}", uri.to_s
    end
  end

  def test_response_from_failed_stock_request
    mock_app_request('fetch_stock', anything, nil)
    response = @service.fetch_stock_levels()
    refute response.success?
    assert_equal "Unable to fetch remote stock levels", response.message
  end

  def test_response_from_failed_tracking_request
    mock_app_request('fetch_tracking_numbers', anything, nil)
    response = @service.fetch_tracking_numbers([1,2])
    refute response.success?
    assert_equal "Unable to fetch remote tracking numbers [1, 2]", response.message
  end

  def test_response_with_invalid_json_is_parsed_to_empty_hash
    bad_json = '{a: 9, 0}'
    mock_app_request('fetch_stock', anything, bad_json)
    assert_equal({}, @service.fetch_stock_levels().stock_levels)
  end

  def test_response_with_valid_but_incorrect_json_is_parsed_to_empty_hash
    incorrect_json = '[]'
    mock_app_request('fetch_stock', anything, incorrect_json)
    assert_equal({}, @service.fetch_stock_levels().stock_levels)
  end

  def test_response_with_invalid_xml_is_parsed_to_empty_hash
    service = build_service(format: 'xml')
    bad_xml = '<A><B></C></A>'
    mock_app_request('fetch_stock', anything, bad_xml)
    assert_equal({}, service.fetch_stock_levels().stock_levels)
  end

  def test_parse_stock_level_response_parses_xml_correctly
    service = build_service(format: 'xml')
    xml = '<StockLevels><Product><Sku>sku1</Sku><Quantity>1</Quantity></Product><Product><Sku>sku2</Sku><Quantity>2</Quantity></Product></StockLevels>'
    expected = {'sku1' => '1', 'sku2' => '2'}

    mock_app_request('fetch_stock', anything, xml)
    assert_equal expected, service.fetch_stock_levels().stock_levels
  end

  def test_parse_tracking_data_response_parses_xml_correctly
    service = build_service(format: 'xml')
    xml = '<TrackingNumbers><Order><ID>123</ID><Tracking>abc</Tracking></Order><Order><ID>456</ID><Tracking>def</Tracking></Order></TrackingNumbers>'
    expected = {'123' => 'abc', '456' => 'def'}

    mock_app_request('fetch_tracking_numbers', anything, xml)
    assert_equal expected, service.fetch_tracking_data([1,2,4]).tracking_numbers
  end

  def test_parse_stock_level_response_parses_json_with_root_correctly
    json = '{"stock_levels": {"998KIB":"10"}}'
    expected = {'998KIB' => "10"}

    mock_app_request('fetch_stock', anything, json)
    assert_equal expected, @service.fetch_stock_levels().stock_levels
  end

  def test_parse_tracking_data_response_parses_json_with_root_correctly
    json = '{"tracking_numbers": {"order1":"a","order2":"b"}}'
    expected = {'order1' => 'a', 'order2' => 'b'}

    mock_app_request('fetch_tracking_numbers', anything, json)
    assert_equal expected, @service.fetch_tracking_data([1,2]).tracking_numbers
  end

  def test_parse_stock_level_response_parses_json_without_root_correctly
    json = '{"998KIB":"10"}'
    expected = {'998KIB' => "10"}

    mock_app_request('fetch_stock', anything, json)
    assert_equal expected, @service.fetch_stock_levels().stock_levels
  end

  def test_parse_tracking_data_response_parses_json_without_root_correctly
    json = '{"order1":"a","order2":"b"}'
    expected = {'order1' => 'a', 'order2' => 'b'}

    mock_app_request('fetch_tracking_numbers', anything, json)
    assert_equal expected, @service.fetch_tracking_data([1,2]).tracking_numbers
  end

  def test_send_app_request_rescues_response_errors
    response = stub(code: "404", message: "Not Found")
    @service.expects(:ssl_get).raises(ActiveMerchant::ResponseError, response)
    refute @service.fetch_stock_levels().success?
  end

  def test_send_app_request_rescues_invalid_response_errors
    @service.expects(:ssl_get).raises(ActiveMerchant::InvalidResponseError.new("error html"))
    refute @service.fetch_stock_levels().success?
  end

  private

  def mock_app_request(action, input, output)
    ShopifyAPIService.any_instance.expects(:send_app_request).with(action, nil, input).returns(output)
  end

  def build_service(options = {})
    options.reverse_merge!({
      name: "fulfillment_app",
      callback_url: 'http://supershopifyapptwin.com',
      format: 'json'
    })
    ShopifyAPIService.new(options)
  end
end
