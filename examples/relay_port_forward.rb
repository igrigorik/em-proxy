require 'lib/em-proxy'

Proxy.start(:host => "0.0.0.0", :port => 80, :debug => false) do |conn|
  # Specifying :relay_server or :relay_client is useful if only requests or responses 
  # need to be processed. The proxy throughput will roughly double.
  conn.server :srv, :host => "127.0.0.1", :port => 81, :relay_client => true, :relay_server => true

  conn.on_connect do
    p [:on_connect, "#{conn.peer.join(':')} connected"]
  end

  # modify / process request stream
  # on_data will not be called when :relay_server => true is passed as server option
  conn.on_data do |data|
    p [:on_data, data]
    data
  end
 
  # modify / process response stream
  # on_response will not be called when :relay_client => true is passed as server option
  conn.on_response do |backend, resp|
    p [:on_response, backend, resp]
    # resp = "HTTP/1.1 200 OK\r\nConnection: close\r\nDate: Thu, 30 Apr 2009 03:53:28 GMT\r\nContent-Type: text/plain\r\n\r\nHar!"
    resp
  end  
end
