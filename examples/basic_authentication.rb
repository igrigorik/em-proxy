# = Proxy with support for HTTP Basic Authentication
#
# An example of proxy with support for authentication. Over-ride the `Credentials#valid?` method
# to load user credentials from a database, etc.
#
# The authentication headers are _not_ passed to the backend.
#
# REQUIRES the <http://rubygems.org/gems/http_parser.rb> Rubygem:
#
#     $ gem install http_parser.rb
#
require 'em-proxy'
require 'base64'
require 'http/parser'

module BasicAuthentication

  # HTTP request: uses http_parser.rb to parse the incoming request
  #
  class Request
    attr_accessor :body, :http_method, :request_url, :headers

    # Bundled responses for authentication request and the forbidden response
    #
    RESPONSES = {
      :request_authentication => "HTTP/1.1 401 Authorization Required\r\nWWW-Authenticate: Basic realm='YOUR NAME'\r\nContent-Type: application/json; charset=UTF-8\r\nContent-Length: 22\r\n\n{\"error\": \"Forbidden\"}",

      :forbidden => "HTTP/1.1 401 Authorization Required\r\nContent-Type: application/json; charset=UTF-8\r\nContent-Length: 22\r\n\n{\"error\": \"Forbidden\"}"
    }

    def initialize(connection)
      @connection = connection
      @body   = ''
      @parser = Http::Parser.new

      # If the request contains a body, pass it to http_parser
      #
      @parser.on_body = lambda do |chunk|
        @body << chunk
      end
    end

    # Pass request data to http_parser
    #
    def << data
      @parser << data
    end

    # Proxy methods for parsed request properties
    #
    def http_method;  @http_method ||= @parser.http_method;   end
    def request_url;  @request_url ||= @parser.request_url;   end
    def headers;      @headers     ||= @parser.headers;       end

    # Get credentials from Authorization header and remove it from headers, so it's not passed to the backend
    #
    def credentials
      @credentials ||= Credentials.new(self.headers.delete("Authorization"))
    end

    # Validate request
    #
    # * Request authentication if no authentication header is not provided
    # * Send "Forbidden" response if credentials are not valid
    #
    def validate!
      unless credentials.username
        @connection.send_data RESPONSES[:request_authentication]
        return
      end

      @connection.send_data RESPONSES[:forbidden] unless credentials.valid?
    end

    # Return request (without the "Authorization" header) if valid
    # 
    # You can modify the request in this method (change the URL according to username, add headers, modify body, etc)
    #
    def to_s
      validate!
      "#{http_method} #{request_url} HTTP/#{@parser.http_version.join('.')}\r\n#{headers.map {|h| "#{h[0]} : #{h[1]}"}.join("\r\n")}\r\n\r\n#{body}"
    end


    # Decoded request credentials
    #
    class Credentials
      attr_reader :username, :password

      def initialize(header)
        @username, @password = Base64.decode64(header.split("Basic").last.strip).split(":") rescue []
      end

      # Check username and password
      #
      # You can load user credentials in this method (from Redis or another database)
      #
      def valid?
        username == "root" && password == "passwd"
      end
    end

  end


  # Defines callbacks for em-proxy
  #
  module Callbacks
    extend self

    def process_request(connection)
      lambda do |data|
        request = Request.new(connection)
        request << data
        request.to_s
      end
    end

  end


  # Proxy server wrapper
  #
  module Server
    def run(options = {})
      host         = options["host"] || "0.0.0.0"
      port         = options["port"] || 9000

      backend_host = options["backend_host"] || "0.0.0.0"
      backend_port = options["backend_port"] || 9200

      puts "Launching proxy at #{host}:#{port}"

      Proxy.start(:host => host, :port => port) do |connection|
        connection.server :backend, :host => backend_host, :port => backend_port

        connection.on_data &Callbacks.process_request(connection)
      end
    end

    module_function :run
  end
end

if __FILE__ == $0
  BasicAuthentication::Server.run
end

