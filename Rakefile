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
    gemspec.add_dependency('rdf', '>= 0.2.1')
    gemspec.add_dependency('nokogiri', '>= 1.3.3')
    gemspec.add_development_dependency('rspec', '~> 1.3.0')
    gemspec.add_development_dependency('rdf-spec', '>= 0.2.1')
    gemspec.add_development_dependency('rdf-rdfxml', '>= 0.2.1')
    gemspec.add_development_dependency('rdf-isomorphic')
    gemspec.add_development_dependency('yard')
    gemspec.extra_rdoc_files     = %w(README.rdoc History.txt AUTHORS CONTRIBUTORS)
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
  spec.rcov_opts = ['-x', '/Library', '-x', '/System/Library', '-x', 'spec']
end

desc "Generate HTML report specs"
Spec::Rake::SpecTask.new("doc:spec") do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/*_spec.rb']
  spec.spec_opts = ["--format", "html:doc/spec.html"]
end

YARD::Rake::YardocTask.new do |t|
  t.files   = %w(lib/**/*.rb README.rdoc History.txt AUTHORS CONTRIBUTORS)   # optional
end

desc "Generate RDF Core Manifest.yml"
namespace :spec do
  task :prepare do
    $:.unshift(File.join(File.dirname(__FILE__), 'lib'))
    require 'rdf/rdfa'
    require 'spec/rdfa_helper'
    require 'fileutils'

    %w(xhtml xhtml11 html4 html5).each do |suite|
      yaml = manifest_file = File.join(File.dirname(__FILE__), "spec", "#{suite}-manifest.yml")
      FileUtils.rm_f(yaml)
      RdfaHelper::TestCase.to_yaml(suite, yaml)
    end
  end
end

task :default => :spec
