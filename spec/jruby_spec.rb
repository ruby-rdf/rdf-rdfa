# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

if RUBY_PLATFORM.to_s == 'jruby'
  # Some specific issues that fail with jRuby to be resolved
  have_nokogiri = true
  begin
    require 'nokogiri'
  rescue LoadError
    have_nokogiri = false
  end

  # Some specific issues that fail with jRuby to be resolved
  describe "JRuby", :no_nokogiri do
    describe "Nokogiri::XML" do
      describe "parse" do
        it "parses namespaced elements without a namespace" do
          expect(Nokogiri::XML.parse("<dc:sup>bar</dc:sup>").root).not_to be_nil
        end
      end
    end

    describe "Nokogiri::HTML", :no_nokogiri do
      describe "xmlns" do
        it "shows namespace definitions" do
          doc = Nokogiri::HTML.parse(%q(<html xmlns:dc="http://purl.org/dc/elements/1.1/"></html>))
          expect(doc.root.namespace_definitions).to be_empty
          expect(doc.root.attributes).not_to be_empty
        end
      end
    end
  end
end
