# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

# Some specific issues that fail with jRuby to be resolved
describe "JRuby" do
  describe Nokogiri::XML do
    describe "parse" do
      it "parses namespaced elements without a namespace" do
        begin
          Nokogiri::XML.parse("<dc:sup>bar</dc:sup>").root.should_not be_nil
        rescue RSpec::Expectations::ExpectationNotMetError => e
          if RUBY_PLATFORM == 'java'
            pending("Nokogiri improvements") {  raise }
          else
            raise
          end
        end
      end
    end
  end

  describe Nokogiri::HTML do
    describe "xmlns" do
      it "shows namespace definitions" do
        begin
          doc = Nokogiri::HTML.parse(%q(<html xmlns:dc="http://purl.org/dc/elements/1.1/"></html>))
          doc.root.namespace_definitions.should be_empty
          doc.root.attributes.should_not be_empty
        rescue RSpec::Expectations::ExpectationNotMetError => e
          if RUBY_PLATFORM == 'java'
            pending("Nokogiri improvements") {  raise }
          else
            raise
          end
        end
      end
    end
  end
end
