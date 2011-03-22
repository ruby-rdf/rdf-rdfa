require 'rubygems'
require 'yard'

begin
  gem 'jeweler'
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "rdf-rdfa"
    gemspec.summary = "RDFa reader for RDF.rb."
    gemspec.description = <<-DESCRIPTION
    RDF::RDFa is an RDFa reader for Ruby using the RDF.rb library suite.
    DESCRIPTION
    gemspec.email = "gregg@kellogg-assoc.com"
    gemspec.homepage = "http://github.com/gkellogg/rdf-rdfa"
    gemspec.authors = ["Gregg Kellogg"]
    gemspec.add_dependency('rdf', '>= 0.3.1')
    gemspec.add_dependency('nokogiri', '>= 1.3.3')
    gemspec.add_development_dependency('spira', '>= 0.0.12')
    gemspec.add_development_dependency('rspec', '>= 2.5.0')
    gemspec.add_development_dependency('rdf-spec', '>= 0.3.1')
    gemspec.add_development_dependency('rdf-rdfxml', '>= 0.3.1')
    gemspec.add_development_dependency('rdf-isomorphic', '>= 0.3.4')
    gemspec.add_development_dependency('yard')
    gemspec.extra_rdoc_files     = %w(README.md History.md AUTHORS CONTRIBUTORS)
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

desc "Run specs through RCov"
RSpec::Core::RakeTask.new("spec:rcov") do |spec|
  spec.rcov = true
  spec.rcov_opts =  %q[--exclude "spec"]
end

desc "Generate HTML report specs"
RSpec::Core::RakeTask.new("doc:spec") do |spec|
  spec.rspec_opts = ["--format", "html", "-o", "doc/spec.html"]
end

YARD::Rake::YardocTask.new do |t|
  t.files   = %w(lib/**/*.rb README.md History.md AUTHORS CONTRIBUTORS UNLICENSE)   # optional
end

task :default => :spec
