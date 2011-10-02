# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rspec/matchers'
require 'equivalent-xml'

# Class for abstract testing of module
class ModuleTester
  attr_reader :base_uri

  def initialize(input, options)

    @library = options[:library] || :nokogiri

    require "rdf/rdfa/reader/#{@library}"
    @implementation = case @library
      when :nokogiri then RDF::RDFa::Reader::Nokogiri
      #when :rexml    then REXML
    end
    self.extend(@implementation)

    initialize_xml(input, options)
  end

  def c14nxl(options)
    self.root.children.c14nxl(options)
  end
end

describe RDF::RDFa::Reader do
  %w(Nokogiri).each do |impl|
    describe impl do
      describe "Exclusive Canonicalization" do
        {
          "no namespace" => [
            %q(<div>foo <sup>bar</sup> baz!</div>),
            {},
            %q(foo <sup>bar</sup> baz!)
          ],
          "namespace" => [
            %q(<div xmlns:dc="http://purl.org/dc/terms/">foo <dc:sup>bar</dc:sup> baz!</div>),
            {},
            %q(foo <dc:sup xmlns:dc="http://purl.org/dc/terms/">bar</dc:sup> baz!)
          ],
          "namespace and language" => [
            %q(<div xmlns:dc="http://purl.org/dc/terms/">foo <dc:sup>bar</dc:sup> baz!</div>),
            {:language => :fr},
            %q(foo <dc:sup xmlns:dc="http://purl.org/dc/terms/" xml:lang="fr">bar</dc:sup> baz!)
          ],
          "namespace and language with existing" => [
            %q(<div xmlns:dc="http://purl.org/dc/terms/">foo <dc:sup>bar</dc:sup><dc:sub xml:lang="en">baz</dc:sub></div>),
            {:language => :fr},
            %q(foo <dc:sup xmlns:dc="http://purl.org/dc/terms/" xml:lang="fr">bar</dc:sup><dc:sub xmlns:dc="http://purl.org/dc/terms/" xml:lang="en">baz</dc:sub>)
          ],
          "0198" => [
            %q(<div xmlns="http://www.w3.org/1999/xhtml" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><span property="foaf:firstName">Mark</span> <span property="foaf:surname">Birbeck</span></div>),
            {},
            %q(<span property="foaf:firstName" xmlns="http://www.w3.org/1999/xhtml" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">Mark</span> <span property="foaf:surname" xmlns="http://www.w3.org/1999/xhtml" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">Birbeck</span>)
          ],
        }.each do |test, (input, options, result)|
          describe test do
            subject {
              mt = ModuleTester.new(input, options.merge(:library => impl.downcase.to_sym))
              mt.c14nxl(options)
            }

            it "matches expected result" do
              # Fixme: why can't I use #be_equivalent_to here?
              EquivalentXml.equivalent?(subject, result).should be_true
            end
          end
        end
      end
    end
  end
end
