module Faraday
  module Multipart
    module ReadablePart
      abstract def to_io : IO::Memory
      abstract def length : Int32
    end

    module Parts
      class Part
        include ReadablePart

        @rendered : String

        getter boundary : String
        getter name : String
        getter headers : HTTP::Headers
        getter body : String

        def initialize(@boundary : String, @name : String, body, headers : HTTP::Headers = HTTP::Headers.new)
          @body = body.to_s
          @headers = clone_headers(headers)
          @headers["Content-Disposition"] ||= %(form-data; name="#{@name}")
          @rendered = render
        end

        def to_io : IO::Memory
          IO::Memory.new(@rendered)
        end

        def length : Int32
          @rendered.bytesize
        end

        private def render : String
          String.build do |io|
            io << "--" << @boundary
            @headers.each do |header, values|
              values.each do |value|
                io << "\r\n" << header << ": " << value
              end
            end
            io << "\r\n\r\n" << @body << "\r\n"
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

      class EpiloguePart
        include ReadablePart

        @rendered : String

        def initialize(boundary : String)
          @rendered = "\r\n--#{boundary}--"
        end

        def to_io : IO::Memory
          IO::Memory.new(@rendered)
        end

        def length : Int32
          @rendered.bytesize
        end
      end
    end
  end
end
