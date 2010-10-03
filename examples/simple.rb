require 'lib/em-proxy'

Proxy.start(:host => "0.0.0.0", :port => 8080, :debug => true) do |conn|
  conn.server :srv, :host => "127.0.0.1", :port => 8081

  # modify / process request stream
  conn.on_data do |data|
    p [:on_data, data]
    data
  end

  # modify / process response stream
  conn.on_response do |backend, resp|
    p [:on_response, backend, resp]
    resp
  end

  # termination logic
  conn.on_finish do |backend, name|
    p [:on_finish, name]

    # terminate connection (in duplex mode, you can terminate when prod is done)
    unbind if backend == :srv
  end
end
