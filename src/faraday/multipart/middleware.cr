require "random/secure"

module Faraday
  module Multipart
    class Middleware < Faraday::Middleware
      CONTENT_TYPE            = "Content-Type"
      DEFAULT_BOUNDARY_PREFIX = "-----------RubyMultipartPost"

      def initialize(app : Faraday::Handler, @options = Options.new)
        super(app)
      end

      def on_request(env : Faraday::Env)
        payload = env.multipart_body
        return unless payload
        return if payload_empty?(payload)

        type = request_type(env)
        return unless (type.empty? && Faraday::Multipart.multipart?(payload)) || type == mime_type

        boundary = env.request.boundary || unique_boundary
        env.request.boundary = boundary
        env.request_headers[CONTENT_TYPE] = "#{mime_type}; boundary=#{boundary}"

        body = create_multipart(boundary, payload)
        env.request_headers[Faraday::Env::CONTENT_LENGTH] = body.length.to_s
        env.body = body.read || ""
      end

      private def request_type(env : Faraday::Env) : String
        value = env.request_headers[CONTENT_TYPE]? || ""
        value.split(";", 2).first || value
      end

      private def payload_empty?(payload : Array) : Bool
        payload.empty?
      end

      private def payload_empty?(payload : Hash) : Bool
        payload.empty?
      end

      private def payload_empty?(payload : Value) : Bool
        false
      end

      private def create_multipart(boundary : String, payload : Value) : CompositeReadIO
        parts = [] of Parts::Part | Parts::EpiloguePart
        append_value(boundary, "", payload, parts)
        parts << Parts::EpiloguePart.new(boundary)
        CompositeReadIO.new(parts)
      end

      private def append_value(boundary : String, key : String, value : Hash, parts : Array(Parts::Part | Parts::EpiloguePart))
        value.each do |child_key, child_value|
          next_key = key.empty? ? child_key.to_s : nested_key(key, child_key)
          append_value(boundary, next_key, child_value.as(Value), parts)
        end
      end

      private def append_value(boundary : String, key : String, value : Array, parts : Array(Parts::Part | Parts::EpiloguePart))
        array_key = @options.flat_encode ? key : "#{key}[]"
        value.each do |child|
          append_value(boundary, array_key, child.as(Value), parts)
        end
      end

      private def append_value(boundary : String, key : String, value : FilePart | ParamPart, parts : Array(Parts::Part | Parts::EpiloguePart))
        parts << value.to_part(boundary, key)
      end

      private def append_value(boundary : String, key : String, value : Value, parts : Array(Parts::Part | Parts::EpiloguePart))
        parts << Parts::Part.new(boundary, key, value.to_s)
      end

      private def nested_key(prefix : String, key) : String
        return prefix if @options.flat_encode
        %(#{prefix}[#{key}])
      end

      private def unique_boundary : String
        "#{DEFAULT_BOUNDARY_PREFIX}-#{Random::Secure.hex(12)}"
      end

      private def mime_type : String
        @mime_type ||= if (content_type = @options.content_type) && content_type.starts_with?("multipart/")
                         content_type
                       else
                         "multipart/form-data"
                       end
      end
    end
  end
end
