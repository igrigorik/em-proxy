require 'lib/em-proxy'
require 'em-http'
require 'yaml'
require 'net/http'

Proxy.start(:host => "0.0.0.0", :port => 2524) do |conn|
  conn.server :srv, :host => "127.0.0.1", :port => 2525

  RCPT_CMD = /RCPT TO:<(.*)?>\r\n/        # RCPT TO:<name@address.com>\r\n
  FROM_CMD = /MAIL FROM:<(.*)?>\r\n/    # MAIL FROM:<ilya@aiderss.com>\r\n
  MSG_CMD = /354 Start your message/   # 354 Start your message
  MSGEND_CMD = /^.\r\n/

  conn.on_data do |data|
    @from = data.match(FROM_CMD)[1] if data.match(FROM_CMD)
    @rcpt = data.match(RCPT_CMD)[1] if data.match(RCPT_CMD)
    @done = true if data.match(MSGEND_CMD)

    if @buffer
      @msg += data
      data = nil
    end

    if @done
      @buffer = false
      res = Net::HTTP.post_form(URI.parse('http://api.defensio.com/app/1.2/audit-comment/77ca297d7546705ee2b5136fad0dcaf8.yaml'), {
          "owner-url" => "http://www.github.com/igrigorik/em-http-request",
          "user-ip" => "216.16.254.254",
          "article-date" => "2009/04/01",
          "comment-author" => @from,
          "comment-type" => "comment",
          "comment-content" => @msg})

      defensio = YAML.load(res.body)['defensio-result']
      p [:defensio, "SPAM: #{defensio['spam']}, Spaminess: #{defensio['spaminess']}"]

      if defensio['spam']
        conn.send_data "550 No such user here\n"
      else
        data = @msg
      end
    end

    data
  end
 
  conn.on_response do |server, resp|
    p [:resp, resp]

    if resp.match(MSG_CMD)
      @buffer = true
      @msg = ""
    end

    resp
  end
end

# mailtrap run -p 2525 -f /tmp/mailtrap.log
# ruby examples/smtp_spam_filter.rb
#
# >> require 'net/smtp'
# >> smtp = Net::SMTP.start("localhost", 2524)
# >> smtp.send_message "Hello World!", "ilya@aiderss.com", "ilya@igvita.com"


# Protocol trace
#
# [:srv, :conn_complete]
# [:srv, "220 localhost MailTrap ready ESTMP\n"]
# [:relay_from_backend, :srv, "220 localhost MailTrap ready ESTMP\n"]
# [:resp, "220 localhost MailTrap ready ESTMP\n"]
# [:connection, "EHLO localhost.localdomain\r\n"]
# [:srv, "250-localhost offers just ONE extension my pretty"]
# [:relay_from_backend, :srv, "250-localhost offers just ONE extension my pretty"]
# [:resp, "250-localhost offers just ONE extension my pretty"]
# [:srv, "\n250 HELP\n"]
# [:relay_from_backend, :srv, "\n250 HELP\n"]
# [:resp, "\n250 HELP\n"]
# [:connection, "MAIL FROM:<ilya@aiderss.com>\r\n"]
# [:srv, "250 OK\n"]
# [:relay_from_backend, :srv, "250 OK\n"]
# [:resp, "250 OK\n"]
# [:connection, "RCPT TO:<ilya@igvita.com>\r\n"]
# [:srv, "250 OK"]
# [:relay_from_backend, :srv, "250 OK"]
# [:resp, "250 OK"]
# [:srv, "\n"]
# [:relay_from_backend, :srv, "\n"]
# [:resp, "\n"]
# [:connection, "DATA\r\n"]
# [:srv, "354 Start your message"]
# [:relay_from_backend, :srv, "354 Start your message"]
# [:resp, "354 Start your message"]
# [:srv, "\n"]
# [:relay_from_backend, :srv, "\n"]
# [:resp, "\n"]
# [:connection, "Hello World\r\n"]
# [:connection, ".\r\n"]
#
# [:defensio, "SPAM: false, Spaminess: 0.4"]
#
# [:srv, "250 OK\n"]
# [:relay_from_backend, :srv, "250 OK\n"]
# [:resp, "250 OK\n"]
#

