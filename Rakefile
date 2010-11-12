require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "em-proxy"
    gemspec.summary = "EventMachine Proxy DSL"
    gemspec.description = gemspec.summary
    gemspec.email = "ilya@igvita.com"
    gemspec.homepage = "http://github.com/igrigorik/em-proxy"
    gemspec.authors = ["Ilya Grigorik"]
    gemspec.add_dependency("eventmachine", ">= 0.12.9")
    gemspec.rubyforge_project = "em-proxy"
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end
