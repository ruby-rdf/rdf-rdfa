$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

unless ENV['CI']  # Skip for continuous integration
  describe "RDF::RDFa::Reader" do
    # W3C Test suite from http://www.w3.org/2006/07/SWD/RDFa/testsuite/
    describe "w3c test cases" do
      require 'suite_helper'
    
      Fixtures::TestCase::HOST_LANGUAGE_VERSION_SETS.each do |(host_language, version)|
        describe "for #{host_language} #{version}" do
          %w(required optional buggy).each do |classification|
            describe "that are #{classification}" do
              Fixtures::TestCase.for_specific(host_language, version, Fixtures::TestCase::Test.send(classification)) do |t|
                specify "test #{t.num}: #{t.description}#{",  (negative test)" if t.expectedResults.false?}" do
                  pending "Invalid SPARQL query" if %w(0279 0284).include?(t.num)
                  begin
                    t.debug = []
                    t.debug << "source:"
                    t.debug << RDF::Util::File.open_file(t.input(host_language, version)).read
                    options = {
                      :base_uri => t.input(host_language, version),
                      :debug => t.debug,
                      :format => :rdfa
                    }
                    if t.queryParam
                      opt, arg = t.queryParam.split('=').map(&:to_sym)
                      options[opt] = arg
                    end

                    validate = %w(0239 0279 0295 0284).none? {|n| t.input(host_language, version).to_s.include?(n)}
                    graph = RDF::Repository.new
                    RDF::Reader.open(t.input(host_language, version), options.merge(:validate => validate)) do |reader|
                      expect(reader).to be_a RDF::RDFa::Reader

                      # Some allowances for REXML
                      if reader.instance_variable_get(:@library) == :rexml && %w(0198 0212 0256).any? {|n| t.num == n}
                        pending "REXML issues"
                      end

                      # Make sure auto-detect works
                      unless host_language =~ /svg/ || t.num == "0216" # due to http-equiv
                        expect(reader.host_language).to produce(host_language.to_sym, t.debug)
                        expect(reader.version).to produce(version.sub(/-.*$/, '').to_sym, t.debug)
                      end

                      graph << reader
                    end

                    RDF::Util::File.open_file(t.results(host_language, version)) do |query|
                      expect(graph).to pass_query(query, t)
                    end
                  rescue RSpec::Expectations::ExpectationNotMetError => e
                    if classification != "required"
                      pending("#{classification} test") {  raise }
                    #elsif t.num == "0319"
                    #  pending("It actually returns a relative result") { raise}
                    else
                      raise
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    def parse(input, options = {})
      @debug = options[:debug] || []
      graph = RDF::Graph.new
      RDF::RDFa::Reader.new(input, options.merge(:debug => @debug)).each do |statement|
        graph << statement
      end
      graph
    end

  end
end
