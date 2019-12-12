# Spira class for manipulating test-manifest style test suites.
# Used for SWAP tests
require 'rdf/turtle'
require 'json/ld'

# For now, override RDF::Utils::File.open_file to look for the file locally before attempting to retrieve it
module RDF::Util
  module File
    REMOTE_PATH = "http://rdfa.info/test-suite/"
    LOCAL_PATH = ::File.expand_path("../test-suite", __FILE__) + '/'

    class << self
      alias_method :original_open_file, :open_file
    end

    ##
    # Override to use Patron for http and https, Kernel.open otherwise.
    #
    # @param [String] filename_or_url to open
    # @param  [Hash{Symbol => Object}] options
    # @option options [Array, String] :headers
    #   HTTP Request headers.
    # @return [IO] File stream
    # @yield [IO] File stream
    def self.open_file(filename_or_url, **options, &block)
      case
      when filename_or_url.to_s =~ /^file:/
        path = filename_or_url[5..-1]
        Kernel.open(path.to_s, options, &block)
      when (filename_or_url.to_s =~ %r{^#{REMOTE_PATH}} && Dir.exist?(LOCAL_PATH))
        #puts "attempt to open #{filename_or_url} locally"
        localpath = filename_or_url.to_s.sub(REMOTE_PATH, LOCAL_PATH)
        response = begin
          ::File.open(localpath)
        rescue Errno::ENOENT => e
          raise IOError, e.message
        end
        document_options = {
          base_uri:     RDF::URI(filename_or_url),
          charset:      Encoding::UTF_8,
          code:         200,
          headers:      {}
        }
        #puts "use #{filename_or_url} locally"
        document_options[:headers][:content_type] = case filename_or_url.to_s
        when /\.html$/    then 'text/html'
        when /\.xhtml$/   then 'application/xhtml+xml'
        when /\.xml$/    then 'application/xml'
        when /\.svg$/    then 'image/svg+xml'
        when /\.ttl$/    then 'text/turtle'
        when /\.ttl$/    then 'text/turtle'
        when /\.jsonld$/ then 'application/ld+json'
        else                  'unknown'
        end

        document_options[:headers][:content_type] = response.content_type if response.respond_to?(:content_type)
        # For overriding content type from test data
        document_options[:headers][:content_type] = options[:contentType] if options[:contentType]

        remote_document = RDF::Util::File::RemoteDocument.new(response.read, **document_options)
        if block_given?
          yield remote_document
        else
          remote_document
        end
      else
        original_open_file(filename_or_url, **options, &block)
      end
    end
  end
end

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

    attr_accessor :logger

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
  end

  manifest = RDFA_INFO.join("manifest.jsonld")
  TestCase.from_jsonld(RDF::Util::File.open_file(manifest) {|f| JSON.load(f.read)})
end
