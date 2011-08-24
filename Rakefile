require 'rubygems'
require 'yard'
require 'rspec/core/rake_task'

namespace :gem do
  desc "Build the rdf-rdfa-#{File.read('VERSION').chomp}.gem file"
  task :build do
    sh "gem build rdf-rdfa.gemspec && mv rdf-rdfa-#{File.read('VERSION').chomp}.gem pkg/"
  end

  desc "Release the rdf-rdfa-#{File.read('VERSION').chomp}.gem file"
  task :release do
    sh "gem push pkg/rdf-rdfa-#{File.read('VERSION').chomp}.gem"
  end
end

RSpec::Core::RakeTask.new(:spec)

desc "Run specs through RCov"
RSpec::Core::RakeTask.new("spec:rcov") do |spec|
  spec.rcov = true
  spec.rcov_opts =  %q[--exclude "spec"]
end

desc "Update RDFa Profiles"
task :update_profiles do
  {
    :xhtml => "http://www.w3.org/profile/html-rdfa-1.1",
    :xml => "http://www.w3.org/profile/rdfa-1.1",
  }.each do |v, uri|
    puts "Build #{uri}"
    vocab = File.expand_path(File.join(File.dirname(__FILE__), "lib", "rdf", "rdfa", "profile", "#{v}.rb"))
    FileUtils.rm(vocab)
    `./script/intern_vocabulary -o #{vocab} #{uri}`
  end
end

namespace :doc do
  YARD::Rake::YardocTask.new

  desc "Generate HTML report specs"
  RSpec::Core::RakeTask.new("spec") do |spec|
    spec.rspec_opts = ["--format", "html", "-o", "doc/spec.html"]
  end
end

task :default => :spec
