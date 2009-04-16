$:.unshift(File.dirname(__FILE__) + '/../lib')

require "rubygems"
require "eventmachine"

%w[ backend server duplex ].each do |file|
  require "em-proxy/#{file}"
end

%w[ duplex_http ].each do |file|
  require "em-proxy/processor/#{file}"
end