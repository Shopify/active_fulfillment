module ActiveMerchant
  module Fulfillment
    class ShipwireBetaService <  ShipwireService

      SERVICE_URLS = { :fulfillment => 'https://api.beta.shipwire.com/exec/FulfillmentServices.php',
                       :inventory   => 'https://api.beta.shipwire.com/exec/InventoryServices.php',
                       :tracking    => 'https://api.beta.shipwire.com/exec/TrackingServices.php'
                     }
    end