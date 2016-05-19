require 'em-proxy'
require 'http/parser' # gem install http_parser.rb
require 'uuid'        # gem install uuid

# > ruby http_proxy.rb
# > curl --proxy localhost:9889 www.google.com
# > curl --proxy x.x.x.x:9889 www.google.com - bind ip example

host = "0.0.0.0"
port = 9889
puts "listening on #{host}:#{port}..."

##----
## Note: 
##    Use of `puts` statements below can cause the loading of corrupt
##    images if using the proxy to view a page like maps.google.com. 
##    You will most likely want to remove these statements if you are
##    using this file as a starting point not only for the reason
##    stated above but, also for performance reasons. 
##----
Proxy.start(:host => host, :port => port) do |conn|
  
  @buffer = ''

  @p = Http::Parser.new
  @p.on_headers_complete = proc do |h|
    session = UUID.generate
    puts "New session: #{session} (#{h.inspect})"

    host, port = h['Host'].split(':')
    conn.server session, :host => host, :port => (port || 80) #, :bind_host => conn.sock[0] - # for bind ip
                         
    conn.relay_to_servers @buffer

    @buffer = ''
  end

  conn.on_connect do |data,b|
    puts [:on_connect, data, b].inspect
  end

  conn.on_data do |data|
    @buffer << data
    @p << data

    data
  end

  conn.on_response do |backend, resp|
    puts [:on_response, backend, resp].inspect
    resp
  end

  conn.on_finish do |backend, name|
    puts [:on_finish, name].inspect
  end
end
