require "rubygems"
require "rack"

app = lambda {
  p  [:serving, ARGV[0]]

	sleep(ARGV[1].to_i)
  [200, {"Content-Type" => "text/plain"}, ["hello world: #{ARGV[1]}"]]
}

Rack::Handler::Mongrel.run(app, {:Host => "0.0.0.0", :Port => ARGV[0]})
