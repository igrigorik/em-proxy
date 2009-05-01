require "rubygems"
require "rack"

app = lambda {
  p  [:serving, ARGV[0]]
  r = rand(2)

	sleep(r)
  [200, {"Content-Type" => "text/plain"}, ["hello world: #{r}"]]
}

Rack::Handler::Mongrel.run(app, {:Host => "0.0.0.0", :Port => ARGV[0]})
