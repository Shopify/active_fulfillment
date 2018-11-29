# encoding: utf-8
$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require 'active_fulfillment/version'

Gem::Specification.new do |s|
  s.name = %q{active_fulfillment}
  s.version = ActiveFulfillment::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.license = "MIT"
  s.authors = ["Cody Fauser", "James MacAulay"]
  s.email = %q{cody@shopify.com}

  s.files       = Dir.glob("{lib}/**/*") + %w(CHANGELOG.md)
  s.test_files  = Dir.glob("{test}/**/*.rb")

  s.homepage = %q{http://github.com/shopify/active_fulfillment}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Framework and tools for dealing with shipping, tracking and order fulfillment services.}

  s.required_ruby_version = '~> 2.2'
  s.add_dependency('activesupport', '>= 4.2.0')
  s.add_dependency('builder', '>= 2.0.0')
  s.add_dependency('active_utils', '~> 3.3.1')
  s.add_dependency('nokogiri', '>= 1.6.8')

  s.add_development_dependency('rake')
  s.add_development_dependency('mocha', '~> 1.1')
  s.add_development_dependency('minitest', '>= 4.7')
  s.add_development_dependency('timecop')
  s.add_development_dependency('pry')
end
