# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "em-proxy"
  s.version     = "0.1.9"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ilya Grigorik"]
  s.email       = ["ilya@igvita.com"]
  s.homepage    = "http://github.com/igrigorik/em-proxy"
  s.summary     = %q{EventMachine Proxy DSL}
  s.description = s.summary

  s.rubyforge_project = "em-proxy"

  s.add_dependency "eventmachine"
  s.add_development_dependency "rspec"
  s.add_development_dependency "em-http-request"
  s.add_development_dependency "ansi"
  s.add_development_dependency "rake"
  s.add_development_dependency "posix-spawn"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
