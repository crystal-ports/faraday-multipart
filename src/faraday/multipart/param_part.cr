module Faraday
  module Multipart
    class ParamPart
      getter value : String
      getter content_type : String
      getter content_id : String?

      def initialize(value, @content_type : String, @content_id : String? = nil)
        @value = value.to_s
      end

      def to_part(boundary : String, key : String) : Parts::Part
        Faraday::Multipart::Parts::Part.new(boundary, key, value, headers)
      end

      def headers : HTTP::Headers
        headers = HTTP::Headers{"Content-Type" => content_type}
        headers["Content-ID"] = content_id.not_nil! if content_id
        headers
      end
    end
  end
end
