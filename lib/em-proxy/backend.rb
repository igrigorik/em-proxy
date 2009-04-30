module EventMachine
  module ProxyServer
    class Backend < EventMachine::Connection
      attr_accessor :plexer, :data, :name

      def initialize
        @connected = EM::DefaultDeferrable.new
        @data = []
      end

      def connection_completed
        p [@name, :conn_complete]
        @connected.succeed
      end

      def receive_data(data)
        p [@name, data]
        @data.push data
        @plexer.relay_from_backend(@name, data)
      end

      # Buffer data until the connection to the backend server
      # is established and is ready for use
      def send(data)
        @connected.callback { send_data data }
      end

      # Notify upstream plexer that the backend server is done
      # processing the request
      def unbind
        p [@name, :unbind]
        @plexer.unbind_backend(@name)
      end
    end
  end
end