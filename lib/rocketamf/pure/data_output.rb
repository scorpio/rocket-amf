module RocketAMF
  module Pure
    class DataOutput

      attr_accessor :stream

      def initialize(stream, decoder)
        if stream.instance_of?(String)
        	@stream = StringIO.new()
          @stream.write(stream)
        else
          @stream = stream
        end
        @decoder = decoder
      end

      def write_boolean(value)
        value = value ? 1 : 0
        @stream.write([value].pack("c"))       
      end

      def write_byte(value)
        @stream.write([value].pack("c"))
      end

      def write_ubyte(value)
        @stream.write([value].pack("C"))
      end

      def write_double(value)
        @stream.write([value].pack("G"))
      end

      def write_float(value)
        @stream.write([value].pack("g"))
      end

      def write_short(value)
        @stream.write([value].pack("s"))
      end

      def write_ushort(value)
        @stream.write([value].pack("n"))
      end

      def write_int(value)
        @stream.write([value].pack("l"))
      end

      def write_uint(value)
        @stream.write([value].pack("N"))
      end

      def write_utf8(value)
        value ||= ""
				#value.encode("UTF-8").force_encoding("ASCII-8BIT") if value.respond_to?(:encode)
        raise "length exceed 64k, you should try write_object" if value.bytesize > 65535
				write_ushort(value.bytesize)
        @stream.write(value)
      end

      def write_object(value)
        @decoder.serialize(value, @stream.string)
        @stream.pos = @stream.string.bytesize
      end

    end
  end
end
