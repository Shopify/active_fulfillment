require 'base64'
require 'openssl'
require 'time'
require 'cgi'

module ActiveMerchant
  module Fulfillment
    class AmazonMarketplaceWebService < Service

      APPLICATION_IDENTIFIER = "active_merchant_mws/0.01 (Language=ruby)"

      SIGNATURE_VERSION = 2
      SIGNATURE_METHOD  = "SHA256"
      VERSION = "2009-01-01"

      ENDPOINTS = {
        :ca => 'mws.amazonservices.ca',
        :cn => 'mws.amazonservices.com.cn',
        :de => 'mws-eu.amazonservices.ca',
        :es => 'mws-eu.amazonservices.ca',
        :fr => 'mws-eu.amazonservices.ca',
        :it => 'mws-eu.amazonservices.ca',
        :jp => 'mws.amazonservices.jp',
        :uk => 'mws-eu.amazonservices.ca',
        :us => 'mws.amazonservices.com'
      }

      OPERATIONS = {
        :outbound => {
          :status => 'GetServiceStatus',
          :create => 'CreateFulfillmentOrder',
          :list   => 'ListAllFulfillmentOrders',
          :tracking => 'GetFulfillmentOrder'
        },
        :inventory => {
          :get  => 'ListInventorySupply',
          :list => 'ListInventorySupply',
          :list_next => 'ListInventorySupply'
        }
      }

      # The first is the label, and the last is the code
      # Standard:  3-5 business days
      # Expedited: 2 business days
      # Priority:  1 business day
      def self.shipping_methods
        [ 
          [ 'Standard Shipping', 'Standard' ],
          [ 'Expedited Shipping', 'Expedited' ],
          [ 'Priority Shipping', 'Priority' ]
        ].inject(ActiveSupport::OrderedHash.new){|h, (k,v)| h[k] = v; h}
      end
      
      def self.sign(aws_secret_access_key, auth_string)
        Base64.encode64(OpenSSL::HMAC.digest(@@digest, aws_secret_access_key, auth_string)).strip
      end

      def initialize(options = {})
        requires!(options, :login, :password)
        options
        super
      end

      def endpoint
        ENDPOINTS[@options[:endpoint] || :us]
      end

      def sign(http_verb, request_uri, options)
        opts = prepare_for_signing(options)
        string_to_sign = "#{http_verb.to_s.upcase}\n"
        string_to_sign += "#{endpoint}\n"
        string_to_sign += "#{request_uri}\n"
        string_to_sign += opts.sort.map{ |key,value| [CGI.escape(key.to_s), CGI.escape(value.to_s)].join('=') }.join('&')
        
        #remove trailing newline created by encode64
        Base64.encode64(OpenSSL::HMAC.digest(SIGNATURE_METHOD, @options[:password], string_to_sign)).chomp
      end

      def prepare_for_signing(options)
        opts = options.dup
        opts["AWSAccessKeyId"] = @options[:login] unless opts["AWSAccessKey"]
        opts["Timestamp"] = Time.now.utc.iso8601 unless opts["Timestamp"]
        opts["Version"] = VERSION unless opts["Version"]
        opts["SignatureMethod"] = "Hmac#{SIGNATURE_METHOD}" unless opts["SignatureMethod"]
        opts["SignatureVersion"] = SIGNATURE_VERSION unless opts["SignatureVersion"]
        opts
      end
    end
  end
end
