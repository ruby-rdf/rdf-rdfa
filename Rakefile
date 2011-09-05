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

desc "Update Cached expansion vocabularies"
task :update_vocabularies do
  {
    :cc     => "http://creativecommons.org/ns#",
    :dc     => "http://purl.org/dc/terms/",
    :doap   => "http://usefulinc.com/ns/doap#",
    :foaf => ['http://xmlns.com/foaf/0.1/', 'http://xmlns.com/foaf/0.1/index.rdf'],
    :gr     => "http://purl.org/goodrelations/v1#",
    :schema => ['http://schema.org/', 'http://schema.rdfs.org/all.ttl'],
    :sioc   => "http://rdfs.org/sioc/ns#",
    :skos   => "http://www.w3.org/2004/02/skos/core#",
    :skosxl => "http://www.w3.org/2008/05/skos-xl#",
    :v      => "http://rdf.data-vocabulary.org/#",
  }.each do |v, loc|
    if loc.is_a?(Array)
      uri, loc = loc
    else
      uri = loc
    end
    puts "Build #{uri} from #{loc}"
    vocab = File.expand_path(File.join(File.dirname(__FILE__), "lib", "rdf", "rdfa", "expansion", "#{v}.rb"))
    FileUtils.rm_rf(vocab)
    `./script/intern_vocabulary -o #{vocab} --uri #{uri} #{loc}`
  end
end

desc "Update RDFa Profiles"
task :update_profiles do
  {
    :xhtml => "http://www.w3.org/profile/html-rdfa-1.1",
    :xml => "http://www.w3.org/profile/rdfa-1.1",
  }.each do |v, uri|
    puts "Build #{uri}"
    vocab = File.expand_path(File.join(File.dirname(__FILE__), "lib", "rdf", "rdfa", "profile", "#{v}.rb"))
    FileUtils.rm_rf(vocab)
    `./script/intern_profile -o #{vocab} #{uri}`
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
