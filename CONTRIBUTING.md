# Contributing to ActiveFulfillment

We welcome fixes and additions to this project. Fork this project, make your changes and submit a pull request!

To add a new fulfillment service, you have to implement the API. The basic Fulfillment Service API can be seen in
[active_fulfillment/service.rb](https://github.com/Shopify/active_fulfillment/blob/master/lib/active_fulfillment/service.rb).

### Code style

Please use clean, concise code that follows Ruby community standards. For example:

- Be consistent
- Don't use too much white space
  - Use 2 space indent, no tabs.
  - No spaces after (, [ and before ],)
- Nor too little
  - Use spaces around operators and after commas, colons and semicolons
  - Indent when as deep as case
- Write lucid code in lieu of adding comments

### Pull request guidelines

- Add unit tests, and remote tests to make sure we won't introduce regressions to your code later on.
- Make sure CI passes for all Ruby versions and dependency versions we support.
- XML handling: use `Nokogiri` for parsing XML, and `builder` to generate it.
- JSON: use the JSON module that is included in Rubys standard ibrary
- HTTP: use `ActiveUtils`'s `PostsData`.
- Do not add new gem dependencies.

### Contributors

- Adrian Irving-Beer
- Arthur Nogueira Neves
- Blake Mesdag
- Chris Saunders (<http://christophersaunders.ca>)
- Cody Fauser
- Denis Odorcic
- Dennis Theisen
- James MacAulay
- Jesse HK
- Jesse Storimer
- John Duff
- John Tajima
- Jonathan Rudenberg
- Kevin Hughes
- Mathieu Rhéaume
- Ryan Romanchuk
- Simon Eskildsen
- Tobias Lütke
- Tom Burns
- Willem van Bergen
