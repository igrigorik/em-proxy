require 'spec/helper'
require 'examples/basic_authentication'

describe BasicAuthentication do

  context "when authorization header is missing" do

    it "should return response requesting login credentials" do
      connection = mock
      connection.should_receive(:send_data).with(BasicAuthentication::Request::RESPONSES[:request_authentication])

      request = BasicAuthentication::Request.new(connection)
      request << "GET / HTTP/1.1\r\nHost: localhost:9000\r\nUser-Agent: Test\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8,application/json\r\nAccept-Language: cs,en-us;q=0.7,en;q=0.3\r\nAccept-Encoding: gzip, deflate\r\nAccept-Charset: ISO-8859-2,utf-8;q=0.7,*;q=0.7\r\nConnection: keep-alive\r\n\r\n"

      request.validate!
    end

  end

  context "when request have authorization header" do

    it "should decode login credentials" do
      connection = mock

      request = BasicAuthentication::Request.new(connection)
      request << "GET / HTTP/1.1\r\nHost: localhost:9000\r\nUser-Agent: Test\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8,application/json\r\nAccept-Language: cs,en-us;q=0.7,en;q=0.3\r\nAccept-Encoding: gzip, deflate\r\nAccept-Charset: ISO-8859-2,utf-8;q=0.7,*;q=0.7\r\nConnection: keep-alive\r\nAuthorization: Basic dXNlcm5hbWU6cGFzc3dvcmQ=\r\n\r\n"

      request.credentials.username.should == "username"
      request.credentials.password.should == "password"
    end

    it "should check if login credentials are valid" do
      connection = mock

      request = BasicAuthentication::Request.new(connection)
      request << "GET / HTTP/1.1\r\nHost: localhost:9000\r\nUser-Agent: Test\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8,application/json\r\nAccept-Language: cs,en-us;q=0.7,en;q=0.3\r\nAccept-Encoding: gzip, deflate\r\nAccept-Charset: ISO-8859-2,utf-8;q=0.7,*;q=0.7\r\nConnection: keep-alive\r\nAuthorization: Basic cm9vdDpwYXNzd2Q=\r\n\r\n"

      request.credentials.valid?.should be_true
    end

    it "should return forbidden response when credentials are invalid" do
      connection = mock
      connection.should_receive(:send_data).with(BasicAuthentication::Request::RESPONSES[:forbidden])

      request = BasicAuthentication::Request.new(connection)
      request << "GET / HTTP/1.1\r\nHost: localhost:9000\r\nUser-Agent: Test\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8,application/json\r\nAccept-Language: cs,en-us;q=0.7,en;q=0.3\r\nAccept-Encoding: gzip, deflate\r\nAccept-Charset: ISO-8859-2,utf-8;q=0.7,*;q=0.7\r\nConnection: keep-alive\r\nAuthorization: Basic dXNlcm5hbWU6cGFzc3dvcmQ=\r\n\r\n"

      request.validate!
    end

    it "should return request without authorization header when credentials are valid" do
      connection = mock

      request = BasicAuthentication::Request.new(connection)
      request << "GET / HTTP/1.1\r\nHost: localhost:9000\r\nUser-Agent: Test\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8,application/json\r\nAccept-Language: cs,en-us;q=0.7,en;q=0.3\r\nAccept-Encoding: gzip, deflate\r\nAccept-Charset: ISO-8859-2,utf-8;q=0.7,*;q=0.7\r\nConnection: keep-alive\r\nAuthorization: Basic cm9vdDpwYXNzd2Q=\r\n\r\n"

      request.to_s.should_not include("Authorization")
    end

  end

end
