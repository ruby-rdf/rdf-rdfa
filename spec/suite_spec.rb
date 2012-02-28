$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

describe "RDF::RDFa::Reader" do
  # W3C Test suite from http://www.w3.org/2006/07/SWD/RDFa/testsuite/
  describe "w3c test cases" do
    require 'suite_helper'
    
    Fixtures::TestCase::HOST_LANGUAGE_VERSION_SETS.each do |(host_language, version)|
      describe "for #{host_language} #{version}" do
        %w(required optional buggy).each do |classification|
          describe "that are #{classification}" do
            Fixtures::TestCase.for_specific(host_language, version, Fixtures::TestCase::Test.send(classification)) do |t|
              #next unless t.name =~ /0231/
              specify "test #{t.name}: #{t.title}#{",  (negative test)" if t.expectedResults.false?}" do
                begin
                  t.debug = []
                  options = {
                    :base_uri => t.input(host_language, version),
                    :debug => t.debug,
                    :format => :rdfa
                  }
                  if t.queryParam
                    opt, arg = t.queryParam.split('=').map(&:to_sym)
                    options[opt] = arg
                  end
                  reader = RDF::Reader.open(t.input(host_language, version), options)
                  reader.should be_a RDF::Reader

                  # Make sure auto-detect works
                  unless host_language =~ /svg/ || t.name == "0216" # due to http-equiv
                    reader.host_language.should == host_language.to_sym
                    reader.version.should == version.to_sym
                  end

                  graph = RDF::Graph.new << reader
                  query = Kernel.open(t.results(host_language, version))
                  graph.should pass_query(query, t)
                rescue RSpec::Expectations::ExpectationNotMetError => e
                  if classification != "required"
                    pending("#{classification} test") {  raise }
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
