module EventMachine
  module ProxyServer
    class Backend < EventMachine::Connection
      attr_accessor :plexer, :name, :debug

      def initialize(debug = false)
        @debug = debug
        @connected = EM::DefaultDeferrable.new
      end

      def connection_completed
        debug [@name, :conn_complete]
        @plexer.connected(@name)
        @connected.succeed
      end

      def receive_data(data)
        debug [@name, data]
        @plexer.relay_from_backend(@name, data)
      end

      # Buffer data until the connection to the backend server
      # is established and is ready for use
      def send(data)
        @connected.callback { send_data data }
      end

      # Notify upstream plexer that the backend server is done
      # processing the request
      def unbind(reason = nil)
        debug [@name, :unbind, reason]
        @plexer.unbind_backend(@name)
      end

      private

      def debug(*data)
        return unless @debug
        require 'pp'
        pp data
        puts
      end
    end
  end
end
