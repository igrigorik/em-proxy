require 'lib/em-proxy'

Proxy.start(:host => "0.0.0.0", :port => 11300) do |conn|
  conn.server :srv, :host => "127.0.0.1", :port => 11301

  # put <pri> <delay> <ttr> <bytes>\r\n
  PUT_CMD = /put (\d+) (\d+) (\d+) (\d+)\r\n/

  conn.on_data do |data|
    if put = data.match(PUT_CMD)

      # archive any job > 10 minutes away
      if put[2].to_i > 600
        p [:put, :archive]
        # INSERT INTO ....

        conn.send_data "INSERTED 9999\r\n"
        data = nil
      end
    end

    data
  end
 
  conn.on_response do |backend, resp|
    p [:resp, resp]
    resp
  end
end

#
# beanstalkd -p 11301 -d
# ruby examples/beanstalkd_interceptor.rb
#
# irb
# >> require 'beanstalk-client'
# >> beanstalk = Beanstalk::Pool.new(['127.0.0.1'])
# >> beanstalk.put("job1")
# => 1
# >> beanstalk.put("job2")
# => 2
# >> beanstalk.put("job3", 0, 1000)
# => 9999
