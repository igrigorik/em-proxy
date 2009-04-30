module EventMachine
  module ProxyServer
    class Connection < EventMachine::Connection

      ##### Proxy Methods
      def on_data(&blk); @on_data = blk; end
      def on_response(&blk); @on_response = blk; end

      ##### EventMachine
      def initialize
        p [:connection, :initialize]
        @servers = {}
      end

      def receive_data(data)
        p [:connection, data]
        data = @on_data.call(data)

        @servers.values.compact.each do |s|
          s.send_data data
        end
      end

      #
      # initialize connections to backend servers
      #
      def server(name, opts)
        srv = EventMachine::connect(opts[:host], opts[:port], EventMachine::ProxyServer::Backend) do |c|
          c.name = name
          c.plexer = self
        end

        @servers[name] = srv
      end

      #
      # relay data from backend server to client
      #
      def relay_from_backend(name, data)
        p [:relay_from_backend, name, data]

        data = @on_response.call(name, data)
        send_data data # if forward
      end

      def unbind
        # terminate any unfinished connections
        @servers.values.compact.each do |s|
          s.close_connection
        end

        close_connection_after_writing
      end

      def unbind_backend(name)
        @servers[name] = nil
        unbind if @servers.values.compact.size.zero?
      end

    end
  end
end