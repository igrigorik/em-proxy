module EventMachine
  module Proxy
    class Duplex < EventMachine::Connection
      attr_accessor :options, :open, :data

      def initialize
        @open = []
        @data = ""
      end

      def receive_data(data)
        @data << data
        proxy_data(data)
      end

      def unbind
        close_connection_after_writing
      end

      #
      # Proxy methods
      #

      # We're duplicating traffic, hence only one response must be sent
      # back to the client. Forward flag determines which connection will
      # forward its data back to the client.
      def relay_from_backend(data, respond)
        send_data data if respond
      end

      # remove backend server from the tracker and terminate connection
      # with the client if all backends have finished processing requests.
      def unbind_backend(respond)
        @open.delete(respond)
        close_backend_connections if @open.empty?
      end

      protected

      def close_backend_connections
        @responder.close_connection_after_writing if @responder
        @benchmark.close_connection_after_writing if @benchmark

        EventMachine::Proxy::PostProcessor::DuplexHttp.new(@responder, @benchmark, @data).process
      end

      def proxy_data(data)
        responder.send(data)
        benchmark.send(data)
      end

      #
      # Open connections to proxy and forward environments
      #

      def responder
        @responder ||= EventMachine::connect(@options[:responder][:host], @options[:responder][:port], EventMachine::Proxy::Backend) do |c|
          c.plexer = self
          c.respond = true
        end
      end

      def benchmark
        @benchmark ||= EventMachine::connect(@options[:benchmark][:host], @options[:benchmark][:port], EventMachine::Proxy::Backend) do |c|
          c.plexer = self
          c.respond = false
        end
      end

    end
  end
end