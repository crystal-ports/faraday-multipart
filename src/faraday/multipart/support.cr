module Faraday
  module Multipart
    alias Scalar = String | Int32 | Int64 | Float32 | Float64 | Bool | Nil | Symbol
    alias Value = Scalar | FilePart | ParamPart | Array(Value) | Hash(String, Value) | Hash(Symbol, Value) | Hash(String | Symbol, Value)

    struct Options
      getter flat_encode : Bool
      getter content_type : String?

      def initialize(@flat_encode = false, @content_type : String? = nil)
      end
    end

    def self.normalize(value : Value) : Value
      value
    end

    def self.normalize(value : Array)
      value.map { |item| normalize(item).as(Value) }
    end

    def self.normalize(value : Hash)
      normalized = {} of String | Symbol => Value
      value.each do |key, item|
        normalized[normalize_key(key)] = normalize(item).as(Value)
      end
      normalized
    end

    def self.normalize(value) : Value
      value.to_s
    end

    def self.multipart?(value : FilePart | ParamPart) : Bool
      true
    end

    def self.multipart?(value : Array) : Bool
      value.any? { |item| multipart?(item.as(Value)) }
    end

    def self.multipart?(value : Hash) : Bool
      value.each_value.any? { |item| multipart?(item.as(Value)) }
    end

    def self.multipart?(value : Value) : Bool
      false
    end

    private def self.normalize_key(key) : String | Symbol
      case key
      when String, Symbol
        key
      else
        key.to_s
      end
    end
  end
end
