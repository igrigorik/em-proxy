module EventMachine
  module ProxyServer
    class Connection < EventMachine::Connection
      attr_accessor :debug

      ##### Proxy Methods
      def on_data(&blk); @on_data = blk; end
      def on_response(&blk); @on_response = blk; end
      def on_finish(&blk); @on_finish = blk; end
      def on_connect(&blk); @on_connect = blk; end

      ##### EventMachine
      def initialize(options)
        @debug = options[:debug] || false
        @servers = {}
      end

      def receive_data(data)
        debug [:connection, data]
        processed = @on_data.call(data) if @on_data

        return if processed == :async or processed.nil?
        relay_to_servers(processed)
      end

      def relay_to_servers(processed)
        if processed.is_a? Array
          data, servers = *processed

          # guard for "unbound" servers
          servers = servers.collect {|s| @servers[s]}.compact
        else
          data = processed
          servers ||= @servers.values.compact
        end

        servers.each do |s|

          s.send_data data unless data.nil?

          ### if you do not care about the reply, we will simply
          ### close the connection to the backend server after we
          ### sent the data to it. Great for doing shadow traffic
          ### --jib
          ### Also, don't wait too long for the connection; if
          ### the remote isn't there, move on as it's affecting
          ### the throughput
          if s.drop_reply then
            debug [:drop_reply, s.name, s.connect_timeout]
            s.pending_connect_timeout = s.connect_timeout
            s.close_connection_after_writing
          end
        end
      end

      #
      # initialize connections to backend servers
      #
      def server(name, opts)
        srv = EventMachine::connect(opts[:host], opts[:port],
            EventMachine::ProxyServer::Backend, @debug, opts[:drop_reply], opts[:connect_timeout] ) do |c|
          c.name = name
          c.plexer = self
          c.proxy_incoming_to(self, 10240) if opts[:relay_server]
        end
        self.proxy_incoming_to(srv, 10240) if opts[:relay_client]

        @servers[name] = srv
      end

      #
      # [ip, port] of the connected client
      #
      def peer
        peername = get_peername
        @peer ||= peername ? Socket.unpack_sockaddr_in(peername).reverse : nil
      end

      #
      # relay data from backend server to client
      #
      def relay_from_backend(name, data)
        debug [:relay_from_backend, name, data]

        data = @on_response.call(name, data) if @on_response
        send_data data unless data.nil?
      end

      def connected(name)
        debug [:connected]
        @on_connect.call(name) if @on_connect
      end

      def unbind
        debug [:unbind, :connection]

        # terminate any unfinished connections
        @servers.values.compact.each do |s|
          s.close_connection
        end
      end

      def unbind_backend(name)
        debug [:unbind_backend, name]
        @servers[name] = nil
        close = :close

        if @on_finish
          close = @on_finish.call(name)
        end

        # if all connections are terminated downstream, then notify client
        if @servers.values.compact.size.zero? and close != :keep
          close_connection_after_writing
        end
      end

      private

      def debug(*data)
        if @debug
          require 'pp'
          pp data
          puts
        end
      end
    end
  end
end
