module EventMachine
  class ProxyServer
    def initialize(opts)
      @options = opts
    end

    def start
      trap("TERM") { stop }
      trap("INT")  { stop }

      EventMachine::start_server(@options[:local][:host], @options[:local][:port], EventMachine::Proxy::Duplex) do |c|
        c.options = @options
      end
    end

    def stop
      puts "Terminating ProxyServer"
      EventMachine.stop
    end
  end
end
