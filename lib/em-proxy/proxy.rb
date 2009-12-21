class Proxy

  def self.start(options, &blk)
    EM.epoll
    EM.run do

      trap("TERM") { stop }
      trap("INT")  { stop }

      EventMachine::start_server(options[:host], options[:port],
                                 EventMachine::ProxyServer::Connection, options) do |c|
        blk.call(c)
      end
    end
  end

  def self.stop
    puts "Terminating ProxyServer"
    EventMachine.stop
  end
end
