spec = Gem::Specification.new do |s|
  s.name = 'em-proxy'
  s.version = '0.1.1'
  s.date = '2009-09-19'
  s.summary = 'EventMachine Proxy DSL'
  s.description = s.summary
  s.email = 'ilya@igvita.com'
  s.homepage = "http://github.com/igrigorik/em-proxy"
  s.has_rdoc = true
  s.authors = ["Ilya Grigorik", "Mark Imbriaco"]
  s.add_dependency('eventmachine', '>= 0.12.2')
  s.rubyforge_project = "em-proxy"

  # ruby -rpp -e' pp `git ls-files`.split("\n") '
  s.files = ["README.rdoc",
    "em-proxy.gemspec",
    "examples/appserver.rb",
    "examples/beanstalkd_interceptor.rb",
    "examples/duplex.rb",
    "examples/line_interceptor.rb",
    "examples/port_forward.rb",
    "examples/selective_forward.rb",
    "examples/smtp_spam_filter.rb",
    "examples/smtp_whitelist.rb",
    "lib/em-proxy.rb",
    "lib/em-proxy/backend.rb",
    "lib/em-proxy/connection.rb",
    "lib/em-proxy/proxy.rb",
    "spec/helper.rb",
    "spec/proxy_spec.rb"]
end
