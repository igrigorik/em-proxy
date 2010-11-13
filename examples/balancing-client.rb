# A simple HTTP client, which sends multiple requests to the proxy server

require 'net/http'

proxy = Net::HTTP::Proxy('0.0.0.0', '9999')

count = ENV['COUNT'] || 5

threads = []
count.to_i.times do |i|
  threads << Thread.new do
    proxy.start('www.example.com') do |http|
      puts http.get('/').body
      puts "^^^ #{i+1} " + '-'*80 + "\n\n"
    end
    sleep 0.1
  end
end

threads.each { |t| t.join }
