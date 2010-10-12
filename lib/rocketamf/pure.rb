require 'rocketamf/pure/deserializer'
require 'rocketamf/pure/serializer'
require 'rocketamf/pure/remoting'
require 'rocketamf/pure/data_input'
require 'rocketamf/pure/data_output'

module RocketAMF
  # This module holds all the modules/classes that implement AMF's functionality
  # in pure ruby
  module Pure
    $DEBUG and warn "Using pure library for RocketAMF."
  end

  #:stopdoc:
  # Import deserializer
  Deserializer = RocketAMF::Pure::Deserializer
  AMF3Deserializer = RocketAMF::Pure::AMF3Deserializer

  # Import serializer
  Serializer = RocketAMF::Pure::Serializer
  AMF3Serializer = RocketAMF::Pure::AMF3Serializer

  # Modify request and response so they can serialize/deserialize
  class Request
    remove_method :populate_from_stream
    include RocketAMF::Pure::Request
  end

  class Response
    remove_method :serialize
    include RocketAMF::Pure::Response
  end
  #:startdoc:
end
