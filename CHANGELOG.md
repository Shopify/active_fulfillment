# ActiveFulfillment changelog

### Version 3.2.6 (November 30, 2018)
- Remove the upperbound constraint on ActiveSupport

### Version 3.2.2
- Add an option to retry Amazon requests upon getting a 503.

### Version 3.2.1

- Allow truncating the Amazon response log.

### Version 3.2.0

- Add support for ActiveSupport 5.1

### Version 3.1.1 (March 2017)

- Bump Nokogiri dependency >= 1.6.8.

### Version 3.1.0 (March 2017)

- Update dependencies

### Version 3.0.1 (January 2015)

- Use Nokogiri for all xml handling.
- Ruby 2.3.0 support.
- Refactor Amazon MWS calls/parsing.
- Freeze constants and hashes.

### Version 2.1.8
- Update dependencies
- Remove old Amazon fulfillment service (use amazon_aws instead)
- Add contributing guidelines

### Version 2.1.7

- Add shopify_api service
- Drop Ruby 1.9.3 support

### Version 2.1.0

- Added fetch_tracking_data methods which returns tracking_companies and tracking_urls if available in addition to tracking_numbers for each service

### Version 2.0.0 (Jan 5, 2013)

- API Change on tracking numbers, returns array instead of single string [csaunders]

### Version 1.0.3 (Jan 21, 2010)

- Include "pending" counts in stock levels for Shipwire [wisq]
- Add option to include pending stock in Shipwire inventory calculations [jessehk]

### Version 1.0.2 (Jan 12, 2010)

- Include "pending" counts in stock levels for Shipwire [wisq]

### Version 1.0.1 (Dec 13, 2010)

- Updated common files with changes from activemerchant [Dennis Theisen]
- Updated Webgistix USPS shipping methods (4 added, 1 removed) [Dennis Theisen]
- Changed Webgistix to treat a duplicate response as success instead of failure and to retry failed connection errors. [Dennis Theisen]

### Version 1.0.0 (July 12, 2010)

- Add inventory support to Amazon and Webgistix [wisq]

### Version 0.10.0 (July 6, 2010)

- Remove DHL from Webgistix shipping methods [Dennis Thiesen]
- Update Amazon FBA to use AWS credentials [John Tajima]
- Use new connection code from ActiveMerchant [cody]
- Add #valid_credentials? support to all fulfillment services [cody]
- Return 'Access Denied' message when Webgistix credenentials are invalid [cody]
- Update Shipwire endpoint hostname [cody]
- Add missing ISO countries [Edward Ocampo-Gooding]
- Add support for Guernsey to country.rb [cody]
- Use a Rails 2.3 compatible OrderedHash [cody]
- Use :words_connector instead of connector in RequiresParameters [cody]
- Provide Webgistix with a valid test sku to keep remote tests passing
- Update PostsData to support get requests
- Update Shipwire to latest version of dtd.
- Use real addresses for Shipwire remote fulfillment tests
- Pass Shipwire the ISO country code instead of the previous name and country combo. Always add the country element to the document
- Update Shipwire warehouses and don't send unneeded Content-Type header
- Add configurable timeouts from Active Merchant
- Shipwire: Send the company in address1 if present. Otherwise send address1 in address1.
- Always send address to Shipwire
- Map company to address1 with Shipwire
- Sync posts_data.rb with ActiveMerchant
- Add support for fetching tracking numbers to Shipwire
- Move email to the options hash. Refactor Shipwire commit method.
- Package for initial upload to Google Code
- Fix remote Webgistix test
- Add support for Fulfillment by Amazon Basic Fulfillment
