require "rubygems"
require "rack"

app = lambda {
  p  [:started, ARGV[0]]

	sleep(ARGV[1].to_f)
  [200, {"Content-Type" => "text/plain"}, ["Hello: #{ARGV[2]}"]]
}

Rack::Handler::Mongrel.run(app, {:Host => "0.0.0.0", :Port => ARGV[0]})