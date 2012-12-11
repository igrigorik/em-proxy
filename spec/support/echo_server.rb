require 'eventmachine'

module EchoServer
  def receive_data data
    send_data ">>>you sent: #{data}"
    close_connection if data =~ /quit/i
  end
end

EventMachine.run do
  if ARGV.count == 2
    EventMachine.start_server ARGV.first, ARGV.last.to_i, EchoServer
  elsif ARGV.count == 1
    EventMachine.start_server ARGV.first, EchoServer
  else
    raise "invalid number of params, expected [server] ([port])"
  end
end
