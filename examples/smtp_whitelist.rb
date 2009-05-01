require 'lib/em-proxy'

Proxy.start(:host => "0.0.0.0", :port => 2524) do |conn|
  conn.server :srv, :host => "127.0.0.1", :port => 2525

  # RCPT TO:<name@address.com>\r\n
  RCPT_CMD = /RCPT TO:<(.*)?>\r\n/

  conn.on_data do |data|
    
    if rcpt = data.match(RCPT_CMD)
      if rcpt[1] != "ilya@igvita.com"
       conn.send_data "550 No such user here\n"
       data = nil
      end
    end

    data
  end
 
  conn.on_response do |backend, resp|
    resp
  end
end


# mailtrap run -p 2525 -f /tmp/mailtrap.log
# ruby examples/smtp_whitelist.rb
#
# >> require 'net/smtp'
# >> smtp = Net::SMTP.start("localhost", 2524)
# >> smtp.send_message "Hello World!", "ilya@aiderss.com", "ilya@igvita.com"
# => #<Net::SMTP::Response:0xb7dcff5c @status="250", @string="250 OK\n">
# >> smtp.finish
# => #<Net::SMTP::Response:0xb7dcc8d4 @status="221", @string="221 Seeya\n">
#
# >> smtp.send_message "Hello World!", "ilya@aiderss.com", "missing_user@igvita.com"
# => Net::SMTPFatalError: 550 No such user here
#
