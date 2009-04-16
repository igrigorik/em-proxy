module EventMachine
  module Proxy
    class Backend < EventMachine::Connection
      attr_accessor :plexer, :respond, :data, :time

      def initialize
        @connected = EM::DefaultDeferrable.new
        @start = Time.now
        @data = ""
      end

      def connection_completed
        @plexer.open.push(@respond)
        @connected.succeed
      end

      def receive_data(data)
        @data << data
        @plexer.relay_from_backend(data, @respond)
      end

      # Buffer data until the connection to the backend server
      # is established and is ready for use
      def send(data)
        @connected.callback { send_data data }
      end

      # Notify upstream plexer that the backend server is done
      # processing the request
      def unbind
        @time = Time.now - @start
        @plexer.unbind_backend(@respond)
      end
    end
  end
end