module ActiveMerchant
  module Fulfillment
    module Base
      mattr_accessor :mode
      self.mode = :production
      
      def self.service(name)
        ActiveMerchant::Fulfillment.const_get("#{name.to_s.downcase}_service".camelize)
      end
    end
  end
end
