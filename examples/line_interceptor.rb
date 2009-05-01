require 'lib/em-proxy'

Proxy.start(:host => "0.0.0.0", :port => 80) do |conn|
  conn.server :srv, :host => "127.0.0.1", :port => 81

  conn.on_data do |data|
    data
  end
 
  conn.on_response do |backend, resp|
    # substitute all mentions of hello to 'good bye', aka intercepting proxy
    resp.gsub(/hello/, 'good bye')
  end  
end

#
# ruby examples/appserver.rb 81
# ruby examples/line_interceptor.rb
# curl localhost
#
# > good bye world: 0
#