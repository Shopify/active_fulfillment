# Copyright (c) 2017 Shopify Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'active_support'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/time/calculations'
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/enumerable'
begin
  require 'active_support/core_ext/time/acts_like'
rescue LoadError
end

require 'builder'
require 'cgi'
require 'net/https'
require 'nokogiri'
require 'active_utils'

require 'active_fulfillment/version'
require 'active_fulfillment/base'
require 'active_fulfillment/response'
require 'active_fulfillment/service'
require 'active_fulfillment/services'
require 'active_fulfillment/parsing'
