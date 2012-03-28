require 'base64'
require 'openssl'

module ActiveMerchant
  module Fulfillment
    class AmazonMarketplaceWebService < Service

      ENDPOINTS = {
        :ca => 'https://mws.amazonservices.ca',
        :cn => 'https://mws.amazonservices.com.cn',
        :de => 'https://mws-eu.amazonservices.ca',
        :es => 'https://mws-eu.amazonservices.ca',
        :fr => 'https://mws-eu.amazonservices.ca',
        :it => 'https://mws-eu.amazonservices.ca',
        :jp => 'https://mws.amazonservices.jp',
        :uk => 'https://mws-eu.amazonservices.ca',
        :us => 'https://mws.amazonservices.com'
      }

      @@digest = OpenSSL::Digest::Digest.new("sha256")

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
        super
      end
    end
  end
end
