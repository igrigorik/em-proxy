require 'helper'

describe Proxy do
  include POSIX::Spawn

  def failed
    EventMachine.stop
    fail
  end

  it "should recieve data on port 8080" do
    EM.run do
      EventMachine.add_timer(0.1) do
        EventMachine::HttpRequest.new('http://127.0.0.1:8080/test').get({:timeout => 1})
      end

      Proxy.start(:host => "0.0.0.0", :port => 8080) do |conn|
        conn.on_data do |data|
          data.should =~ /GET \/test/
          EventMachine.stop
        end
      end
    end
  end

  it "should call the on_connect callback" do
    connected = false
    EM.run do
      EventMachine.add_timer(0.1) do
        EventMachine::HttpRequest.new('http://127.0.0.1:8080/').get({:timeout => 1})
      end

      Proxy.start(:host => "0.0.0.0", :port => 8080) do |conn|
        conn.server :goog, :host => "google.com", :port => 80

        conn.on_connect do |name|
          connected = true
          EventMachine.stop
        end
      end
    end
    connected.should == true
  end


  it "should transparently redirect TCP traffic to google" do
    EM.run do
      EventMachine.add_timer(0.1) do
        EventMachine::HttpRequest.new('http://127.0.0.1:8080/').get({:timeout => 1})
      end

      Proxy.start(:host => "0.0.0.0", :port => 8080) do |conn|
        conn.server :goog, :host => "google.com", :port => 80
        conn.on_data { |data| data }

        conn.on_response do |backend, resp|
          backend.should == :goog
          resp.size.should >= 0
          EventMachine.stop
        end
      end
    end
  end

  it "should duplex TCP traffic to two backends" do
    EM.run do
      EventMachine.add_timer(0.1) do
        EventMachine::HttpRequest.new('http://127.0.0.1:8080/test').get({:timeout => 1})
      end

      Proxy.start(:host => "0.0.0.0", :port => 8080) do |conn|
        conn.server :goog1, :host => "google.com", :port => 80
        conn.server :goog2, :host => "google.com", :port => 80
        conn.on_data { |data| data }

        seen = []
        conn.on_response do |backend, resp|
          case backend
          when :goog1 then
            resp.should =~ /404/
            seen.push backend
          when :goog2
            resp.should =~ /404/
            seen.push backend
          end
          seen.uniq!

          EventMachine.stop if seen.size == 2
        end

        conn.on_finish do |name|
          # keep the connection open if we're still expecting a response
          seen.count == 2 ? :close : :keep
        end

      end
    end
  end

  it "should intercept & alter response from Google" do
    EM.run do
      EventMachine.add_timer(0.1) do
        http = EventMachine::HttpRequest.new('http://127.0.0.1:8080/').get({:timeout => 1})
        http.errback { failed }
        http.callback {
          http.response_header.status.should == 404
          EventMachine.stop
        }
      end

      Proxy.start(:host => "0.0.0.0", :port => 8080) do |conn|
        conn.server :goog, :host => "google.com", :port => 80
        conn.on_data { |data| data }
        conn.on_response do |backend, data|
          data.gsub(/^HTTP\/1.1 301/, 'HTTP/1.1 404')
        end
      end
    end
  end

  it "should invoke on_finish callback when connection is terminated" do
    EM.run do
      EventMachine.add_timer(0.1) do
        EventMachine::HttpRequest.new('http://127.0.0.1:8080/').get({:timeout => 1})
      end

      Proxy.start(:host => "0.0.0.0", :port => 8080) do |conn|
        conn.server :goog, :host => "google.com", :port => 80
        conn.on_data { |data| data }
        conn.on_response { |backend, resp| resp }
        conn.on_finish do |backend|
          backend.should == :goog
          EventMachine.stop
        end
      end
    end
  end

  it "should not invoke on_data when :relay_client is passed as server option" do
    lambda {
      EM.run do
        EventMachine.add_timer(0.1) do
          http = EventMachine::HttpRequest.new('http://127.0.0.1:8080/').get({:timeout => 1})
          http.callback { EventMachine.stop }
        end

        Proxy.start(:host => "0.0.0.0", :port => 8080) do |conn|
          conn.server :goog, :host => "google.com", :port => 80, :relay_client => true
          conn.on_data { |data| raise "Should not be here"; data }
          conn.on_response { |backend, resp| resp }

        end
      end
    }.should_not raise_error
  end

  it "should not invoke on_response when :relay_server is passed as server option" do
    lambda {
      EM.run do
        EventMachine.add_timer(0.1) do
          http = EventMachine::HttpRequest.new('http://127.0.0.1:8080/').get({:timeout => 1})
          http.callback { EventMachine.stop }
        end

        Proxy.start(:host => "0.0.0.0", :port => 8080) do |conn|
          conn.server :goog, :host => "google.com", :port => 80, :relay_server => true
          conn.on_data { |data| data }
          conn.on_response { |backend, resp| raise "Should not be here"; }

        end
      end
    }.should_not raise_error
  end

  context "echo server" do
    before :each do
      @echo_server = File.expand_path("../../spec/support/echo_server.rb", __FILE__)
    end

    context "with a server listening on a TCP port" do
      before :each do
        @host = '127.0.0.1'
        @port = 4242
        @pid  = spawn("ruby #{@echo_server} #{@host} #{@port}")
        sleep 1 # let the server come up
      end
      after :each do
        Process.kill('QUIT', @pid)
      end
      it "should connect to a unix socket" do
        connected = false
        EM.run do
          EventMachine.add_timer(0.1) do
            EventMachine::HttpRequest.new('http://127.0.0.1:8080/').get({:timeout => 1})
          end
          host = @host
          port = @port
          Proxy.start(:host => "0.0.0.0", :port => 8080) do |conn|
            conn.server :local, :host => host, :port => port
            conn.on_connect do |name|
              connected = true
              EventMachine.stop
            end
          end
        end
        connected.should == true
      end
    end

    context "with a server listening on a unix socket" do
      before :each do
        @socket = File.join(Dir.tmpdir, 'em-proxy.sock')
        @pid  = spawn("ruby #{@echo_server} #{@socket}")
        sleep 1 # let the server come up
      end
      after :each do
        Process.kill('QUIT', @pid)
      end
      it "should connect to a unix socket" do
        connected = false
        EM.run do
          EventMachine.add_timer(0.1) do
            EventMachine::HttpRequest.new('http://127.0.0.1:8080/').get({:timeout => 1})
          end
          socket = @socket
          Proxy.start(:host => "0.0.0.0", :port => 8080) do |conn|
            conn.server :local, :socket => socket
            conn.on_connect do |name|
              connected = true
              EventMachine.stop
            end
          end
        end
        connected.should == true
      end
    end
  end

end
