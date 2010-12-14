require 'rocketamf/pure/io_helpers'

module RocketAMF
  module Pure
    # AMF0 implementation of serializer
    class Serializer
      def initialize
        @ref_cache = SerializerCache.new :object
      end

      def version
        0
      end

      def serialize obj, stream = ""
        if obj.respond_to?(:to_amf)
          stream << obj.to_amf(self)
        elsif @ref_cache[obj] != nil
          write_reference @ref_cache[obj], stream
        elsif obj.is_a?(NilClass)
          write_null stream
        elsif obj.is_a?(TrueClass) || obj.is_a?(FalseClass)
          write_boolean obj, stream
        elsif obj.is_a?(Float) || obj.is_a?(Integer)
          write_number obj, stream
        elsif obj.is_a?(Symbol) || obj.is_a?(String)
          write_string obj.to_s, stream
        elsif obj.is_a?(Time)
          write_date obj, stream
        elsif obj.is_a?(Array)
          write_array obj, stream
        elsif obj.is_a?(Hash)
          write_hash obj, stream
        elsif obj.is_a?(Object)
          write_object obj, stream
        end
        stream
      end

      def write_null stream
        stream << AMF0_NULL_MARKER
      end

      def write_boolean bool, stream
        stream << AMF0_BOOLEAN_MARKER
        stream << pack_int8(bool ? 1 : 0)
      end

      def write_number num, stream
        stream << AMF0_NUMBER_MARKER
        stream << pack_double(num)
      end

      def write_string str, stream
        str = str.encode("UTF-8").force_encoding("ASCII-8BIT") if str.respond_to?(:encode)
        len = str.bytesize
        if len > 2**16-1
          stream << AMF0_LONG_STRING_MARKER
          stream << pack_word32_network(len)
        else
          stream << AMF0_STRING_MARKER
          stream << pack_int16_network(len)
        end
        stream << str
      end

      def write_date date, stream
        stream << AMF0_DATE_MARKER

        date = date.getutc
        seconds = (date.to_f * 1000).to_i
        stream << pack_double(seconds)

        stream << pack_int16_network(0)
      end

      def write_reference index, stream
        stream << AMF0_REFERENCE_MARKER
        stream << pack_int16_network(index)
      end

      def write_array array, stream
        @ref_cache.add_obj array
        stream << AMF0_STRICT_ARRAY_MARKER
        stream << pack_word32_network(array.length)
        array.each do |elem|
          serialize elem, stream
        end
      end

      def write_hash hash, stream
        @ref_cache.add_obj hash
        stream << AMF0_HASH_MARKER
        stream << pack_word32_network(hash.length)
        write_prop_list hash, stream
      end

      def write_object obj, stream
        @ref_cache.add_obj obj

        # Is it a typed object?
        class_name = RocketAMF::ClassMapper.get_as_class_name obj
        if class_name
          class_name = class_name.encode("UTF-8").force_encoding("ASCII-8BIT") if class_name.respond_to?(:encode)
          stream << AMF0_TYPED_OBJECT_MARKER
          stream << pack_int16_network(class_name.bytesize)
          stream << class_name
        else
          stream << AMF0_OBJECT_MARKER
        end

        write_prop_list obj, stream
      end

      private
      include RocketAMF::Pure::WriteIOHelpers
      def write_prop_list obj, stream
        # Write prop list
        props = RocketAMF::ClassMapper.props_for_serialization obj
        props.sort.each do |key, value| # Sort keys before writing
          key = key.encode("UTF-8").force_encoding("ASCII-8BIT") if key.respond_to?(:encode)
          stream << pack_int16_network(key.bytesize)
          stream << key
          serialize value, stream
        end

        # Write end
        stream << pack_int16_network(0)
        stream << AMF0_OBJECT_END_MARKER
      end
    end

    # AMF3 implementation of serializer
    class AMF3Serializer
      attr_reader :string_cache

      def initialize
        @string_cache = SerializerCache.new :string
        @object_cache = SerializerCache.new :object
        @trait_cache = SerializerCache.new :trait
      end

      def version
        3
      end

      def serialize obj, stream = ""
        if obj.respond_to?(:to_amf)
          stream << obj.to_amf(self)
        elsif obj.is_a?(NilClass)
          write_null stream
        elsif obj.is_a?(TrueClass)
          write_true stream
        elsif obj.is_a?(FalseClass)
          write_false stream
        elsif obj.is_a?(Float)
          write_float obj, stream
        elsif obj.is_a?(Integer)
          write_integer obj, stream
        elsif obj.is_a?(Symbol) || obj.is_a?(String)
          write_string obj.to_s, stream
        elsif obj.is_a?(Time)
          write_date obj, stream
        elsif obj.is_a?(Date)
          write_date obj.to_time, stream
        elsif obj.is_a?(StringIO)
          write_byte_array obj, stream
        elsif obj.is_a?(RocketAMF::Values::ArrayCollection)
          write_array_collection obj, stream
        elsif obj.is_a?(Array)
          write_array obj, stream
        elsif obj.is_a?(Hash) || obj.is_a?(Object)
          write_object obj, stream
        end
        stream
      end

      def write_reference index, stream
        header = index << 1 # shift value left to leave a low bit of 0
        stream << pack_integer(header)
      end

      def write_null stream
        stream << AMF3_NULL_MARKER
      end

      def write_true stream
        stream << AMF3_TRUE_MARKER
      end

      def write_false stream
        stream << AMF3_FALSE_MARKER
      end

      def write_integer int, stream
        if int < MIN_INTEGER || int > MAX_INTEGER # Check valid range for 29 bits
          write_float int.to_f, stream
        else
          stream << AMF3_INTEGER_MARKER
          stream << pack_integer(int)
        end
      end

      def write_float float, stream
        stream << AMF3_DOUBLE_MARKER
        stream << pack_double(float)
      end

      def write_string str, stream
        stream << AMF3_STRING_MARKER
        write_utf8_vr str, stream
      end

      def write_date date, stream
        stream << AMF3_DATE_MARKER
        if @object_cache[date] != nil
          write_reference @object_cache[date], stream
        else
          # Cache date
          @object_cache.add_obj date

          # Build AMF string
          date = date.getutc unless date.utc?
          seconds = (date.to_f * 1000).to_i
          stream << pack_integer(AMF3_NULL_MARKER)
          stream << pack_double(seconds)
        end
      end

      def write_byte_array array, stream
        stream << AMF3_BYTE_ARRAY_MARKER
        if @object_cache[array] != nil
          write_reference @object_cache[array], stream
        else
          @object_cache.add_obj array
          write_utf8_vr array.string, stream
        end
      end

      def write_array_collection array, stream
        write_object array, stream, {:class_name => RocketAMF::ClassMapper.get_as_class_name(array), :members => [], :externalizable => true, :dynamic => false}
      end

      def write_array array, stream
        stream << AMF3_ARRAY_MARKER
        if @object_cache[array] != nil
          write_reference @object_cache[array], stream
        else
          # Cache array
          @object_cache.add_obj array

          # Build AMF string
          header = array.length << 1 # make room for a low bit of 1
          header = header | 1 # set the low bit to 1
          stream << pack_integer(header)
          stream << AMF3_CLOSE_DYNAMIC_ARRAY
          array.each do |elem|
            serialize elem, stream
          end
        end
      end

      def write_object obj, stream, traits=nil
        stream << AMF3_OBJECT_MARKER
        if @object_cache[obj] != nil
          write_reference @object_cache[obj], stream
        else
          # Cache object
          @object_cache.add_obj obj

          # Calculate traits if not given
          if traits.nil?
            is_hash = obj.is_a? Hash
            traits = {
                      :class_name => RocketAMF::ClassMapper.get_as_class_name(obj),
                      :members => [],
                      :externalizable => !is_hash,
                      :dynamic => is_hash
                     }
          end

          # Write out traits
          if false && traits[:class_name] && @trait_cache[traits] != nil
            stream << pack_integer(@trait_cache[traits] << 2 | 0x01)
          else
            @trait_cache.add_obj traits if traits[:class_name]

            # Write out trait header
            header = 0x03 # Not object ref and not trait ref
            header |= 0x02 << 2 if traits[:dynamic]
            header |= 0x01 << 2 if traits[:externalizable]
            header |= traits[:members].length << 4
            stream << pack_integer(header)

            # Write out class name
            write_utf8_vr(traits[:class_name].to_s, stream)

            # Write out members
            traits[:members].each {|m| write_utf8_vr(m, stream)}
          end

          # If externalizable, take externalized data shortcut
          if traits[:externalizable]
            if obj.respond_to?(:write_amf)
					    output = RocketAMF::Pure::DataOutput.new(stream, self)
					    obj.write_amf(output)
					    stream.replace(output.stream.string)
            else
            	serialize obj.externalized_data, stream
            end
            return
          end

          # Write out sealed properties
          props = RocketAMF::ClassMapper.props_for_serialization obj
          traits[:members].each do |m|
            serialize props[m], stream
            props.delete(m)
          end

          if traits[:dynamic]
            # Write out dynamic properties
            props.sort.each do |key, val| # Sort props until Ruby 1.9 becomes common
              write_utf8_vr key.to_s.dup, stream
              serialize val, stream
            end

            # Write close
            stream << AMF3_CLOSE_DYNAMIC_OBJECT
          end
        end
      end

      private
      include RocketAMF::Pure::WriteIOHelpers

      def write_utf8_vr str, stream
        #str = str.encode("UTF-8").force_encoding("ASCII-8BIT") if str.respond_to?(:encode)

        if str == ''
          stream << AMF3_EMPTY_STRING
        elsif @string_cache[str] != nil
          write_reference @string_cache[str], stream
        else
          # Cache string
          @string_cache.add_obj str

          # Build AMF string
          header = str.bytesize << 1 # make room for a low bit of 1
          header = header | 1 # set the low bit to 1
          stream << pack_integer(header)
          stream << str
        end
      end
    end

    class SerializerCache #:nodoc:
      def self.new type
        if type == :string
          StringCache.new
        elsif type == :object
          ObjectCache.new
        elsif type == :trait
          TraitCache.new
        end
      end

      class StringCache < Hash #:nodoc:
        def initialize
          @cache_index = 0
        end

        def add_obj str
          self[str] = @cache_index
          @cache_index += 1
        end
      end

      class ObjectCache < Hash #:nodoc:
        def initialize
          @cache_index = 0
        end

        def [] obj
          super(obj.object_id)
        end

        def add_obj obj
          self[obj.object_id] = @cache_index
          @cache_index += 1
        end
      end

      class TraitCache < Hash #:nodoc:
        def initialize
          @cache_index = 0
        end

        def [] obj
          super(obj[:class_name])
        end

        def add_obj obj
          self[obj[:class_name]] = @cache_index
          @cache_index += 1
        end
      end
    end
  end
end
