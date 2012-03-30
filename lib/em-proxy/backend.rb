module EventMachine
  module ProxyServer
    class Backend < EventMachine::Connection
      attr_accessor :plexer, :name, :debug, :drop_reply, :connect_timeout

      ### the replies from duplex servers may not be interesting,
      ### so add an option to drop them. Slow duplex servers can
      ### introduce wait time for next connection --jib
      def initialize(debug = false, drop_reply = false, connect_timeout = 5)
        @debug = debug
        @connected = EM::DefaultDeferrable.new
        @drop_reply = drop_reply
        @connect_timeout = connect_timeout
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
      def unbind
        debug [@name, :unbind]
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
