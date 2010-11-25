module RocketAMF
  module Pure
    class DataInput

      attr_accessor :stream

      def initialize(stream, decoder)
        if stream.instance_of?(String)
        	@stream = StringIO.new(stream)
        else
          @stream = stream
        end
        @decoder = decoder
      end

      def read_boolean
        byte = @stream.read(1)
        if byte == "\x01"
          true
        elsif byte == "\x00"
          false
        else
          raise "Error reading boolean"
        end
      end

      def read_byte
        @stream.read(1).unpack('c')[0]
      end

      def read_ubyte
        @stream.read(1).unpack('C')[0]
      end

      def read_double
        @stream.read(8).unpack('G')[0]
      end

      def read_float
        @stream.read(4).unpack('g')[0]
      end

      def read_short
        @stream.read(2).unpack('s')[0]
      end

      def read_ushort
        @stream.read(2).unpack('n')[0]
      end

      def read_int
        @stream.read(4).unpack('l')[0]
      end

      def read_uint
        @stream.read(4).unpack('N')[0]
      end

      def read_utf8
        length = read_ushort
        value = @stream.read(length)
        value.force_encoding("UTF-8") if value.respond_to?(:force_encoding)
        value
      end

      def read_object
        @decoder.deserialize(@stream)
      end

    end
  end
end
