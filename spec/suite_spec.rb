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
                  skip "CDN messes up email addresses" if %w(0065 0176).include?(t.num)
                  pending "Nokogumbo error" if t.num == "0216" && host_language == "xhtml5"
                  skip "XMLLiteral" if %w(0198 0212).include?(t.num)
                  begin
                    t.logger = RDF::Spec.logger
                    t.logger.info t.inspect
                    t.logger.info "source:\n#{RDF::Util::File.open_file(t.input(host_language, version)).read}"
                    options = {
                      base_uri: t.input(host_language, version),
                      logger: t.logger,
                      format: :rdfa
                    }
                    if t.queryParam
                      opt, arg = t.queryParam.split('=').map(&:to_sym)
                      options[opt] = arg
                    end

                    validate = %w(0239 0279 0295 0284).none? {|n| t.input(host_language, version).to_s.include?(n)}
                    graph = RDF::Repository.new
                    RDF::Reader.open(t.input(host_language, version), options.merge(validate: validate)) do |reader|
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

                      expect {graph << reader}.not_to raise_error, t.logger.to_s
                    end

                    RDF::Util::File.open_file(t.results(host_language, version)) do |query|
                      expect(graph).to pass_query(query, t)
                    end
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
  end
end
