module ActiveFulfillment
  module Parsing
    module_function

    def with_xml_document(xml, response = {})
      begin
        document = Nokogiri::XML(xml)
      rescue Nokogiri::XML::SyntaxError
        return response
      end

      yield document, response
    end
  end
end
