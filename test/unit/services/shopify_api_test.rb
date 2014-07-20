require 'test_helper'

class ShopifyAPITest < Test::Unit::TestCase

  # mock Shopify API permission
  class ApiPermission
  end

  def setup
    @service = build_service()
  end

  def test_request_uri_is_correct_when_no_sku_passed
    Timecop.freeze do
      uri = @service.send(:request_uri, 'fetch_stock', {})
      timestamp = Time.now.utc.to_i
      assert_equal "http://supershopifyapptwin.com/fetch_stock.json?shop=www.snowdevil.ca&timestamp=#{timestamp}", uri.to_s
    end
  end

  def test_request_uri_is_correct_when_sku_is_passed
    Timecop.freeze do
      uri = @service.send(:request_uri, 'fetch_stock', {sku: "123"})
      timestamp = Time.now.utc.to_i
      assert_equal "http://supershopifyapptwin.com/fetch_stock.json?shop=www.snowdevil.ca&sku=123&timestamp=#{timestamp}", uri.to_s
    end
  end

  def test_response_with_invalid_json_is_parsed_to_empty_hash
    bad_json = '{a: 9, 0}'
    mock_app_request('fetch_stock', anything, bad_json)
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

  # def test_send_app_request_rescues_response_errors
  #   response = stub(code: "404", message: "Not Found")
  #   @service.expects(:ssl_get).raises(ActiveMerchant::ResponseError, response)

  #   assert_raises(FulfillmentError) do
  #     @service.fetch_stock_levels().stock_levels
  #   end
  # end

  private

  def mock_app_request(action, input, output)
    ShopifyAPIService.any_instance.expects(:send_app_request).with(action, input).returns(output)
  end

  def build_service(options = {})
    options.reverse_merge!({
      domain: 'www.snowdevil.ca',
      callback_url: 'http://supershopifyapptwin.com',
      format: 'json',
      api_permission: ApiPermission.new,
      name: "fulfillment_app"
    })
    ShopifyAPIService.new(options)
  end
end
