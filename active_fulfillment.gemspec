# encoding: utf-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'active_fulfillment/version'

Gem::Specification.new do |s|
  s.name = %q{active_fulfillment}
  s.version = ActiveMerchant::Fulfillment::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Cody Fauser", "James MacAulay"]
  s.email = %q{cody@shopify.com}

  s.files       = Dir.glob("{lib}/**/*") + %w(CHANGELOG)
  s.test_files  = Dir.glob("{test}/**/*")

  s.homepage = %q{http://github.com/shopify/active_fulfillment}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Framework and tools for dealing with shipping, tracking and order fulfillment services.}

  s.add_dependency('activesupport', '>= 3.2.9')
  s.add_dependency('builder', '>= 2.0.0')
  s.add_dependency('active_utils', '~> 2.2.0')

  s.add_development_dependency('rake')
  s.add_development_dependency('byebug')
  s.add_development_dependency('mocha')
  s.add_development_dependency('minitest')
  s.add_development_dependency('timecop')
  s.add_development_dependency('rdoc', '>= 2.4.2')
end
