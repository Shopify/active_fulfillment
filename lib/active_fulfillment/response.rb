module ActiveFulfillment
  class Response
    attr_reader :params
    attr_reader :message
    attr_reader :test

    def success?
      @success
    end

    def test?
      @test
    end

    def initialize(success, message, params = {}, options = {})
      @success, @message, @params = success, message, params.stringify_keys
      @test = options[:test] || false
    end

    private

    def method_missing(method, *args)
      @params[method.to_s] || super
    end
  end

  class FulfillmentResponse < Response
  end

  class TrackingResponse < Response
    def tracking_numbers
      @params['tracking_numbers']
    end

    def tracking_urls
      @params.fetch('tracking_urls', {})
    end

    def tracking_companies
      @params.fetch('tracking_companies', {})
    end
  end

  class StockLevelsResponse < Response
    def stock_levels
      @params['stock_levels']
    end
  end

end
