module ActiveFulfillment
  module Base
    mattr_accessor :mode
    self.mode = :production

    def self.service(name)
      ActiveFulfillment.const_get("#{name.to_s.downcase}_service".camelize)
    end
  end
end
