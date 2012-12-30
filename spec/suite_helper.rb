# Spira class for manipulating test-manifest style test suites.
# Used for SWAP tests
require 'rdf/turtle'
require 'json/ld'

module Fixtures
  RDFA_INFO = RDF::URI("http://rdfa.info/test-suite/")

  class TestCase < JSON::LD::Resource
    HOST_LANGUAGE_VERSION_SETS = [
      ["xhtml1",      "rdfa1.1"],
      ["xml1",        "rdfa1.1"],
      ["html5",       "rdfa1.1"],
      ["xhtml5",      "rdfa1.1"],
      ["xhtml5",      "rdfa1.1-role"],
      ["xhtml5",      "rdfa1.1-proc"],
      ["xhtml5",      "rdfa1.1-vocab"],
      ["xhtml1",      "rdfa1.0"],
      ["svgtiny1.2",  "rdfa1.0"],
      ["svg",         "rdfa1.1"],
    ]

    class Test < RDF::Vocabulary("http://www.w3.org/2006/03/test-description#"); end

    attr_accessor :debug

    # @param [Hash] json framed JSON-LD`
    # @return [Array<TestCase>]
    def self.from_jsonld(json)
      @@test_cases ||= json['@graph'].map {|e| TestCase.new(e)}
    end

    def self.for_specific(host_language, version, classification = nil)
      @@test_cases.each do |tc|
        yield(tc) if tc.hostLanguages.include?(host_language) &&
                     tc.versions.include?(version) &&
                     (classification.nil? || tc.classification == classification)
      end
    end

    def information; id; end

    def expectedResults
      RDF::Literal::Boolean.new(property('expectedResults'))
    end

    def input(host_language, version)
      base = self.property('input').to_s.
        sub('test-cases/', "test-cases/#{version}/#{host_language}/")
      case host_language
      when /^xml/   then RDF::URI(base.sub(".html", ".xml"))
      when /^xhtml/ then RDF::URI(base.sub(".html", ".xhtml"))
      when /^svg/   then RDF::URI(base.sub(".html", ".svg"))
      else               RDF::URI(base)
      end
    end
    
    def results(host_language, version)
      RDF::URI(self.property('results').to_s.
        sub('test-cases/', "test-cases/#{version}/#{host_language}/"))
    end

    def trace
      @debug.to_a.join("\n")
    end
  end

  manifest = RDF::URI(RDFA_INFO.join("manifest.json"))
  TestCase.from_jsonld(JSON.load(Kernel.open(manifest).read))
end