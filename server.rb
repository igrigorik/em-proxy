require "lib/em-proxy"
require "optparse"
require "yaml"

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: server.rb -c config"
  opts.on("-c", "--config config.yml", String, "Load configuration file") do |v|
    options[:config] = v
  end.parse!
end

unless !options[:config].nil? && File.exists?(options[:config])
   puts "Invalid config file #{options[:config]}"
   exit 1
end

options.merge!(YAML.load(File.read(options[:config])))

puts options.inspect

EventMachine.run do
  EventMachine::ProxyServer.new(options).start
end
