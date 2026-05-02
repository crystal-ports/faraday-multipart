module Faraday
  module Multipart
    class CompositeReadIO
      @parts : Array(ReadablePart)
      @rendered : String
      @offset : Int32

      def initialize
        @parts = [] of ReadablePart
        @rendered = ""
        @offset = 0
      end

      def initialize(*parts : ReadablePart)
        @parts = parts.to_a.map { |part| part.as(ReadablePart) }
        @rendered = render_parts
        @offset = 0
      end

      def initialize(parts : Array(T)) forall T
        @parts = parts.map { |part| part.as(ReadablePart) }
        @rendered = render_parts
        @offset = 0
      end

      def length : Int32
        @rendered.bytesize
      end

      def size : Int32
        length
      end

      def rewind
        @offset = 0
      end

      def read(length : Int? = nil, outbuf : String? = nil) : String?
        return nil if length && @offset >= @rendered.bytesize

        chunk = if length
                  @rendered.byte_slice(@offset, length) || ""
                else
                  @rendered.byte_slice(@offset, @rendered.bytesize - @offset) || ""
                end
        @offset += chunk.bytesize

        outbuf ? chunk : chunk
      end

      def close
      end

      def ensure_open_and_readable
      end

      private def render_parts : String
        String.build do |io|
          @parts.each do |part|
            io << part.to_io.to_s
          end
        end
      end
    end
  end
end
