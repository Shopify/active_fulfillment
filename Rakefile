require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'

desc "Default Task"
task :default => 'test:units'

# Run the unit tests

namespace :test do
  Rake::TestTask.new(:units) do |t|
    t.pattern = 'test/unit/**/*_test.rb'
    t.ruby_opts << '-rubygems'
    t.libs << 'test'
    t.verbose = true
  end

  Rake::TestTask.new(:remote) do |t|
    t.pattern = 'test/remote/*_test.rb'
    t.ruby_opts << '-rubygems'
    t.libs << 'test'
    t.verbose = true
  end
end

# Genereate the RDoc documentation
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "ActiveFulfillment library"
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

task :install => [:package] do
  `gem install pkg/#{PKG_FILE_NAME}.gem`
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = 'activefulfillment'
    gemspec.summary = "Framework and tools for dealing with shipping, tracking and order fulfillment services."
    gemspec.email = "cody@shopify.com"
    gemspec.homepage = "http://github.com/shopify/active_fulfillment"
    gemspec.authors = ["Cody Fauser", "James MacAulay"]
  end
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end
