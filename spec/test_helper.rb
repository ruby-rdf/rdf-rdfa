# Spira class for manipulating test-manifest style test suites.
# Used for SWAP tests
require 'spira'
require 'rdf/n3'
require 'open-uri'

module Fixtures
  SUITE = RDF::URI("http://rdfa.digitalbazaar.com/test-suite/")

  class TestCase
    HTMLRE = Regexp.new('([0-9]{4,4})\.xhtml')
    TCPATHRE = Regexp.compile('\$TCPATH')

    HOST_LANGUAGE_VERSION_SETS = [
      ["xhtml1",      "rdfa1.1"],
      ["xml1",        "rdfa1.1"],
      ["html4",       "rdfa1.1"],
      ["html5",       "rdfa1.1"],
      ["xhtml5",      "rdfa1.1"],
      ["xhtml1",      "rdfa1.0"],
      ["svgtiny1.2",  "rdfa1.0"],
      ["svg",         "rdfa1.1"],
    ]

    class Test < RDF::Vocabulary("http://www.w3.org/2006/03/test-description#"); end
    class RdfaTest < RDF::Vocabulary("http://rdfa.digitalbazaar.com/vocabs/rdfa-test#"); end

    attr_accessor :debug
    include Spira::Resource

    type Test.TestCase
    property :title,          :predicate => DC11.title,                   :type => XSD.string
    property :purpose,        :predicate => Test.purpose,                 :type => XSD.string
    has_many :hostLanguage,   :predicate => RdfaTest.hostLanguage,        :type => XSD.string
    has_many :version,        :predicate => RdfaTest.rdfaVersion,         :type => XSD.string
    property :expected,       :predicate => Test.expectedResults
    property :contributor,    :predicate => DC11.contributor,             :type => XSD.string
    property :reference,      :predicate => Test.specificationRefference, :type => XSD.string
    property :classification, :predicate => Test.classification
    property :inputDocument,  :predicate => Test.informationResourceInput
    property :resultDocument, :predicate => Test.informationResourceResults

    def self.for_specific(host_language, version, classification = nil)
      each do |tc|
        yield(tc) if tc.hostLanguage.include?(host_language) &&
                     tc.version.include?(version) &&
                     (classification.nil? || tc.classification == classification)
      end
    end
    
    def expectedResults
      RDF::Literal::Boolean.new(expected.nil? ? "true" : expected)
    end
    
    def name
      subject.to_s.split("/").last
    end

    def input(host_language, version)
      base = self.inputDocument.to_s.sub('test-cases/', "test-cases/#{host_language}/#{version}/")
      case host_language
      when /^xml/   then RDF::URI(base.sub(".html", ".xml"))
      when /^xhtml/ then RDF::URI(base.sub(".html", ".xhtml"))
      when /^svg/   then RDF::URI(base.sub(".html", ".svg"))
      else               RDF::URI(base)
      end
    end
    
    def results(host_language, version)
      RDF::URI(self.resultDocument.to_s.sub('test-cases/', "test-cases/#{host_language}/#{version}/"))
    end

    def trace
      @debug.to_a.join("\n")
    end
    
    def inspect
      "[#{self.class.to_s} " + %w(
        title
        classification
        hostLanguage
        version
        inputDocument
        resultDocument
      ).map {|a| v = self.send(a); "#{a}='#{v}'" if v}.compact.join(", ") +
      "]"
    end
  end

  local_manifest = File.join(File.expand_path(File.dirname(__FILE__)), 'rdfa-test-suite', 'manifest.ttl')
  repo = if File.exist?(local_manifest)
    RDF::Repository.load(local_manifest, :base_uri => SUITE.join("manifest.ttl"), :format => :n3)
  else
    RDF::Repository.load(SUITE.join("manifest.ttl"), :format => :n3)
  end
  Spira.add_repository! :default, repo
end