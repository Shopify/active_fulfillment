# ActiveFulfillment [![Build Status](https://travis-ci.org/Shopify/active_fulfillment.png?branch=master)](https://travis-ci.org/Shopify/active_fulfillment)

Library for integration with order fulfillment services.

## Installation

Add to your gem file, and run `bundle install`.

```
gem 'active_fulfillment'
```

## Usage

```
# The authentication options differ per service.
service = ActiveFulfillment.service('name').new(login: 'abc', password: 'def')

# To fulfill an order:
service.fulfill(order_id, shipping_address, line_items, options = {})

# To find out how much stock is left
service.fetch_stock_levels(options = {})

# To obtain tracking numbers.
service.fetch_tracking_numbers(order_ids, options = {})

```

The options hash is used to set service-specific options. See http://www.rubydoc.info/gems/active_fulfillment for the API documentation.

## Other information

- This project is MIT licensed.
- Contributions are welcomed! See CONTRIBUTING.md for more information.
