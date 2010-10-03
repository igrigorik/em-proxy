require "rubygems"
require "rack"

app = Proc.new do
  p  [:serving, ARGV[0]]

  sleep(ARGV[1].to_i)
  [200, {"Content-Type" => "text/plain"}, ["hello world: #{ARGV[1]}"]]
end

Rack::Handler::Mongrel.run(app, {:Host => "0.0.0.0", :Port => ARGV[0]})
