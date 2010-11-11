require 'spec/helper'

describe Proxy do

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
          resp.should =~ /google/
          EventMachine.stop
        end
      end
    end
  end

  it "should duplex TCP traffic to two backends google & yahoo" do
    EM.run do
      EventMachine.add_timer(0.1) do
        EventMachine::HttpRequest.new('http://127.0.0.1:8080/test').get({:timeout => 1})
      end

      Proxy.start(:host => "0.0.0.0", :port => 8080) do |conn|
        conn.server :goog, :host => "google.com", :port => 80
        conn.server :yhoo, :host => "yahoo.com", :port => 80
        conn.on_data { |data| data }

        seen = []
        conn.on_response do |backend, resp|
          case backend
          when :goog then
            resp.should =~ /404/
            seen.push backend
          when :yhoo
            resp.should =~ /404/
            seen.push backend
          end
          seen.uniq!

          EventMachine.stop if seen.size == 2
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
          data.gsub(/^HTTP\/1.1 200/, 'HTTP/1.1 404')
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
          http =EventMachine::HttpRequest.new('http://127.0.0.1:8080/').get({:timeout => 1})
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
          http =EventMachine::HttpRequest.new('http://127.0.0.1:8080/').get({:timeout => 1})
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
end

require 'examples/balancing'
require 'rack'

describe BalancingProxy do

  before(:each) do
    class BalancingProxy::Backend
      @list = nil; @pool = nil
    end
  end

  before(:all) do
    @original_stdout = $stdout
    # Silence the noisy STDOUT output
    $stdout = File.new('/dev/null', 'w')
  end

  after(:all) do
    $stdout = @original_stdout
  end

  context "when using the 'random' strategy" do

    it "should select random backend" do
      class BalancingProxy::Backend
        def self.list
          @list ||= [
            {"http://127.0.0.1:3000" => 0},
            {"http://127.0.0.2:3000" => 0},
            {"http://127.0.0.3:3000" => 0}
          ]
        end
      end

      srand(0)
      BalancingProxy::Backend.select(:random).host.should == '127.0.0.1'
    end

  end

  context "when using the 'roundrobin' strategy" do
    it "should select backends in rotating order" do
      class BalancingProxy::Backend
        def self.list
          @list ||= [
            {"http://127.0.0.1:3000" => 0},
            {"http://127.0.0.2:3000" => 0},
            {"http://127.0.0.3:3000" => 0}
          ]
        end
      end

      BalancingProxy::Backend.select(:roundrobin).host.should == '127.0.0.1'
      BalancingProxy::Backend.select(:roundrobin).host.should == '127.0.0.2'
      BalancingProxy::Backend.select(:roundrobin).host.should == '127.0.0.3'
      BalancingProxy::Backend.select(:roundrobin).host.should == '127.0.0.1'
    end
  end

  context "when using the 'balanced' strategy" do

    it "should select the first backend when all backends have the same load" do
      class BalancingProxy::Backend
        def self.list
          @list ||= [
            {"http://127.0.0.3:3000" => 0},
            {"http://127.0.0.2:3000" => 0},
            {"http://127.0.0.1:3000" => 0}
          ]
        end
      end

      BalancingProxy::Backend.select.host.should == '127.0.0.3'
    end

    it "should select the least loaded backend" do
      class BalancingProxy::Backend
        def self.list
          @list ||= [
            {"http://127.0.0.3:3000" => 2},
            {"http://127.0.0.2:3000" => 1},
            {"http://127.0.0.1:3000" => 0}
          ]
        end
      end

      BalancingProxy::Backend.select.host.should == '127.0.0.1'
      BalancingProxy::Backend.select.host.should == '127.0.0.1'
      BalancingProxy::Backend.select.host.should == '127.0.0.2'
      BalancingProxy::Backend.select.host.should == '127.0.0.3'
    end

  end

end
