# EM-Proxy

[![Build Status](https://travis-ci.org/igrigorik/em-proxy.png?branch=master)](https://travis-ci.org/igrigorik/em-proxy)

EventMachine Proxy DSL for writing high-performance transparent / intercepting proxies in Ruby.

- EngineYard tutorial: [Load testing your environment using em-proxy](http://docs.engineyard.com/em-proxy.html)
- [Slides from RailsConf 2009](http://bit.ly/D7oWB)
- [GoGaRuCo notes & Slides](http://www.igvita.com/2009/04/20/ruby-proxies-for-scale-and-monitoring/)

## Getting started

    $> gem install em-proxy
    $> em-proxy
    Usage: em-proxy [options]
      -l, --listen [PORT]              Port to listen on
      -d, --duplex [host:port, ...]    List of backends to duplex data to
      -r, --relay [hostname:port]      Relay endpoint: hostname:port
      -s, --socket [filename]          Relay endpoint: unix filename
      -v, --verbose                    Run in debug mode

    $> em-proxy -l 8080 -r localhost:8081 -d localhost:8082,localhost:8083 -v

The above will start em-proxy on port 8080, relay and respond with data from port 8081, and also (optional) duplicate all traffic to ports 8082 and 8083 (and discard their responses).


## Simple port forwarding proxy

```ruby
Proxy.start(:host => "0.0.0.0", :port => 80, :debug => true) do |conn|
  conn.server :srv, :host => "127.0.0.1", :port => 81

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
```

For more examples see the /examples directory.

- SMTP Spam Filtering
- Duplicating traffic
- Selective forwarding
- Beanstalkd interceptor
- etc.

A schema-free MySQL proof of concept, via an EM-Proxy server:

- http://www.igvita.com/2010/03/01/schema-free-mysql-vs-nosql/
- Code in examples/schemaless-mysql

## License

The MIT License - Copyright (c) 2010 Ilya Grigorik
