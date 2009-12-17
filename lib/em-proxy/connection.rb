module EventMachine
  module ProxyServer
    class Connection < EventMachine::Connection
      attr_accessor :debug
      
      ##### Proxy Methods
      def on_data(&blk); @on_data = blk; end
      def on_response(&blk); @on_response = blk; end
      def on_finish(&blk); @on_finish = blk; end

      ##### EventMachine
      def initialize(options)
        @debug = options[:debug] || false
        @servers = {}
      end

      def receive_data(data)
        debug [:connection, data]
        processed = @on_data.call(data)

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
        end
      end

      #
      # initialize connections to backend servers
      #
      def server(name, opts)
        srv = EventMachine::connect(opts[:host], opts[:port], EventMachine::ProxyServer::Backend, @debug) do |c|
          c.name = name
          c.plexer = self
        end

        @servers[name] = srv
      end

      #
      # relay data from backend server to client
      #
      def relay_from_backend(name, data)
        debug [:relay_from_backend, name, data]

        data = @on_response.call(name, data)
        send_data data unless data.nil?
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

        # if all connections are terminated downstream, then notify client
        close_connection_after_writing if @servers.values.compact.size.zero?
        
        if @on_finish
          @on_finish.call(name)
          @on_finish.call(:done) if @servers.values.compact.size.zero?
        end
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
