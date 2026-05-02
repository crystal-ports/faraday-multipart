module Faraday
  module Multipart
    class FilePart
      getter content_type : String
      getter original_filename : String
      getter opts : HTTP::Headers

      def initialize(source : String | IO, @content_type : String, filename : String? = nil, opts : HTTP::Headers | Hash(String, String) = HTTP::Headers.new)
        @opts = normalize_headers(opts)

        case source
        when String
          @original_filename = filename || File.basename(source)
          @body = File.read(source)
        else
          @original_filename = filename || "local.path"
          @body = source.gets_to_end
          source.rewind if source.responds_to?(:rewind)
        end
      end

      def io : IO::Memory
        IO::Memory.new(@body)
      end

      def to_part(boundary : String, key : String) : Parts::Part
        headers = normalize_headers(@opts)
        disposition = headers["Content-Disposition"]? || "form-data"
        headers["Content-Disposition"] = %(#{disposition}; name="#{key}"; filename="#{@original_filename}")
        headers["Content-Type"] = headers["Content-Type"]? || @content_type
        headers["Content-Transfer-Encoding"] = headers["Content-Transfer-Encoding"]? || "binary"

        Parts::Part.new(boundary, key, @body, headers)
      end

      private def normalize_headers(headers : HTTP::Headers | Hash(String, String)) : HTTP::Headers
        case headers
        when HTTP::Headers
          clone_headers(headers)
        else
          built = HTTP::Headers.new
          headers.each do |name, value|
            built[name] = value
          end
          built
        end
      end

      private def clone_headers(headers : HTTP::Headers) : HTTP::Headers
        copy = HTTP::Headers.new
        headers.each do |name, values|
          values.each do |value|
            copy.add(name, value)
          end
        end
        copy
      end
    end
  end
end
