require 'helper'
require File.join(File.dirname(__FILE__), '../', 'examples/balancing')

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

  context "generally" do

    it "should raise error for unknown strategy" do
      lambda { BalancingProxy::Backend.select(:asdf)}.should raise_error(ArgumentError)
    end

  end

  context "when using the 'random' strategy" do

    it "should select random backend" do
      class BalancingProxy::Backend
        def self.list
          @list ||= [
            {:url => "http://127.0.0.1:3000"},
            {:url => "http://127.0.0.2:3000"},
            {:url => "http://127.0.0.3:3000"}
          ].map { |backend| new backend }
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
            {:url => "http://127.0.0.1:3000"},
            {:url => "http://127.0.0.2:3000"},
            {:url => "http://127.0.0.3:3000"}
          ].map { |backend| new backend }
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
            {:url => "http://127.0.0.3:3000", :load => 0},
            {:url => "http://127.0.0.2:3000", :load => 0},
            {:url => "http://127.0.0.1:3000", :load => 0}
          ].map { |backend| new backend }
        end
      end

      BalancingProxy::Backend.select.host.should == '127.0.0.3'
    end

    it "should select the least loaded backend" do
      class BalancingProxy::Backend
        def self.list
          @list ||= [
            {:url => "http://127.0.0.3:3000", :load => 4},
            {:url => "http://127.0.0.2:3000", :load => 2},
            {:url => "http://127.0.0.1:3000", :load => 0}
          ].map { |backend| new backend }
        end
      end

      BalancingProxy::Backend.select.host.should == '127.0.0.1'
      BalancingProxy::Backend.select.host.should == '127.0.0.1'
      BalancingProxy::Backend.select.host.should_not == '127.0.0.3'
      BalancingProxy::Backend.select.host.should_not == '127.0.0.3'
    end

  end

end
