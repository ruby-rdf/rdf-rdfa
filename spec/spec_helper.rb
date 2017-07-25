$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require "bundler/setup"
require 'rubygems'
require 'rspec'
require 'yaml'
require 'rdf/isomorphic'
require 'rdf/spec'
require 'rdf/spec/matchers'
require 'rdf/turtle'
require 'rdf/vocab'
require_relative 'matchers'

begin
  require 'nokogiri'
rescue LoadError
end
begin
  require 'simplecov'
  require 'coveralls'
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ])
  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/lib/rdf/rdfa/reader/rexml.rb"
    add_filter "/lib/rdf/rdfa/context.rb"
  end
rescue LoadError
end
require 'rdf/rdfa'

::RSpec.configure do |c|
  c.filter_run focus: true
  c.run_all_when_everything_filtered = true
  c.exclusion_filter = {
    ruby:     lambda { |version| !(RUBY_VERSION.to_s =~ /^#{version}/) },
  }
  c.include(RDF::Spec::Matchers)
end

TMP_DIR = File.join(File.expand_path(File.dirname(__FILE__)), "tmp")

# Heuristically detect the input stream
def detect_format(stream)
  # Got to look into the file to see
  if stream.is_a?(IO) || stream.is_a?(StringIO)
    stream.rewind
    string = stream.read(1000)
    stream.rewind
  else
    string = stream.to_s
  end
  case string
  when /<html/i   then RDF::RDFa::Reader
  when /@prefix/i then RDF::Turtle::Reader
  else                 RDF::NTriples::Reader
  end
end
