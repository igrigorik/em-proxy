require 'lib/em-proxy'

Proxy.start(:host => "0.0.0.0", :port => 8000, :debug => true) do |conn|
  @start = Time.now
  @data = Hash.new("")

  conn.server :prod, :host => "127.0.0.1", :port => 8100    # production, will render resposne
  conn.server :test, :host => "127.0.0.1", :port => 8200    # testing, internal only

  conn.on_data do |data|
    # rewrite User-Agent
    data.gsub(/User-Agent: .*?\r\n/, "User-Agent: em-proxy/0.1\r\n")
  end

  conn.on_response do |server, resp|
    # only render response from production
    @data[server] += resp
    resp if server == :prod
  end

  conn.on_finish do |name|
    p [:on_finish, name, Time.now - @start]
    p @data
    :close if name == :prod
  end
end

#
# ruby examples/appserver.rb 8100 1
# ruby examples/appserver.rb 8200 3
# ruby examples/line_interceptor.rb
# curl localhost:8000
#
# > [:on_finish, 1.008561]
# > {:prod=>"HTTP/1.1 200 OK\r\nConnection: close\r\nDate: Fri, 01 May 2009 04:20:00 GMT\r\nContent-Type: text/plain\r\n\r\nhello world: 0",
#       :test=>"HTTP/1.1 200 OK\r\nConnection: close\r\nDate: Fri, 01 May 2009 04:20:00 GMT\r\nContent-Type: text/plain\r\n\r\nhello world: 1"}
#
