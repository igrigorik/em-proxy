require 'lib/em-proxy'
require 'ansi/code'
require 'rack'

module BalancedProxy
  extend self

  BACKENDS = [
    {"http://0.0.0.0:3000"  => 0},
    {"http://0.0.0.0:3001" => 0},
    {"http://0.0.0.0:3002"  => 0}
  ]

  # Represents a "backend", ie. the endpoint for the proxy.
  #
  # This could be eg. a WEBrick webserver (see below), so the proxy server works as a _reverse_ proxy.
  # But it could also be a proxy server, so the proxy server works as a _forward_ proxy.
  #
  class Backend

    attr_reader :url, :host, :port
    alias       :to_s :url

    def initialize(url)
      @url = url
      parsed = URI.parse(@url)
      @host, @port = parsed.host, parsed.port
    end

    # Select the least loaded backend
    #
    def self.select
      backend = new list.sort { |a,b| a.values <=> b.values }.first.keys.first
      puts "---> Selecting #{backend}"
      backend.increment_counter
      yield backend if block_given?
      backend
    end

    # List of backends
    #
    def self.list
      @list ||= BACKENDS
    end

    # Increment "currently serving requests" counter
    #
    def increment_counter
      Backend.list.select { |b| b.keys.first == url }.first[url] += 1
    end

    # Decrement "currently serving requests" counter
    #
    def decrement_counter
      Backend.list.select { |b| b.keys.first == url }.first[url] -= 1
    end

  end

  # Callbacks for em-proxy events
  #
  module Callbacks
    include ANSI::Code
    extend  self

    def on_connect
      lambda do |backend|
        puts black_on_magenta { 'on_connect'.ljust(12) } + ' ' + bold { backend }
      end
    end

    def on_data
      lambda do |data|
        puts black_on_yellow { 'on_data'.ljust(12) }, data
        data
      end
    end

    def on_response
      lambda do |backend, resp|
        puts black_on_green { 'on_response'.ljust(12) } + " from #{backend}", resp
        resp
      end
    end

    def on_finish
      lambda do |backend|
        puts black_on_magenta { 'on_finish'.ljust(12) } + " for #{backend}", ''
        backend.decrement_counter
      end
    end

  end

  # Wrapping the proxy server
  #
  module Server
    def run(host='0.0.0.0', port=9999)

      puts ANSI::Code.bold { "Launching proxy at #{host}:#{port}...\n" }

      Proxy.start(:host => host, :port => port, :debug => false) do |conn|

        Backend.select do |backend|

          conn.server backend, :host => backend.host, :port => backend.port

          conn.on_connect  &Callbacks.on_connect
          conn.on_data     &Callbacks.on_data
          conn.on_response &Callbacks.on_response
          conn.on_finish   &Callbacks.on_finish
        end

      end
    end

    module_function :run
  end

end

if __FILE__ == $0

  class Proxy
    def self.stop
      puts "Terminating ProxyServer"
      EventMachine.stop
      $servers.each do |pid|
        puts "Terminating webserver #{pid}"
        Process.kill('KILL', pid)
      end
    end
  end

  # Simple Rack app to run
  app = proc { |env| [ 200, {'Content-Type' => 'text/plain'}, ["Hello World!"] ] }

  # Run app on ports 3000-3002
  $servers = []
  3.times do |i|
    $servers << Process.fork { Rack::Handler::WEBrick.run(app, {:Host => "0.0.0.0", :Port => "300#{i}"}) }
  end

  # Start proxy
  BalancedProxy::Server.run

end
