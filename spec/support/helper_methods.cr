require "http/formdata"
require "mime/media_type"

module Faraday
  module Multipart
    struct ParsedPart
      getter part : HTTP::FormData::Part
      getter body : String

      def initialize(@part : HTTP::FormData::Part, @body : String)
      end

      delegate name, filename, headers, to: @part

      def mime : String?
        headers["Content-Type"]?
      end
    end

    class ParsedMultipart
      getter errors : Array(String)
      getter parts : Array(ParsedPart)

      def initialize
        @errors = [] of String
        @parts = [] of ParsedPart
      end

      def part(name : String) : ParsedPart?
        @parts.find { |entry| entry.name == name }
      end
    end

    module HelperMethods
      extend self

      def multipart_file
        Faraday::Multipart::FilePart.new(__FILE__, "text/x-ruby")
      end

      def parse_multipart_boundary(content_type : String) : String
        MIME::MediaType.parse(content_type)["boundary"]
      end

      def parse_multipart(boundary : String, body : String) : ParsedMultipart
        result = ParsedMultipart.new
        begin
          parser = HTTP::FormData::Parser.new(IO::Memory.new(body), boundary)

          parser.next do |part|
            result.parts << ParsedPart.new(part, part.body.gets_to_end.sub(/\r\n\z/, ""))
          end
        rescue ex : HTTP::FormData::Error | MIME::Multipart::Error
          result.errors << ex.message.to_s
        end
        result
      end
    end
  end
end
