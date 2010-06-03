require 'rubygems'

begin
  gem 'jeweler'
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "rdf-rdfa"
    gemspec.summary = "RDFa parser for RDF.rb."
    gemspec.description = <<-DESCRIPTION
    RDF::RDFa is an RDFa parser for Ruby using the RDF.rb library suite.
    DESCRIPTION
    gemspec.email = "gregg@kellogg-assoc.com"
    gemspec.homepage = "http://github.com/gkellogg/rdf-rdfa"
    gemspec.authors = ["Gregg Kellogg", "Nicholas Humfrey"]
    gemspec.add_dependency('rdf', '>= 0.1.6')
    gemspec.add_dependency('nokogiri', '>= 1.3.3')
    gemspec.add_dependency('patron', '>= 0.4.6')
    gemspec.add_development_dependency('rspec')
    gemspec.add_development_dependency('rdf-spec')
    gemspec.add_development_dependency('activesupport', '>= 2.3.0')
    gemspec.extra_rdoc_files     = %w(README.rdoc History.txt AUTHORS)
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/*_spec.rb']
end

desc "Run specs through RCov"
Spec::Rake::SpecTask.new("spec:rcov") do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/*_spec.rb'
  spec.rcov = true
end

desc "Generate HTML report specs"
Spec::Rake::SpecTask.new("doc:spec") do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/*_spec.rb']
  spec.spec_opts = ["--format", "html:doc/spec.html"]
end

task :default => :spec
