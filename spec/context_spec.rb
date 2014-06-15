$:.unshift "."
require 'spec_helper'

describe RDF::RDFa::Context do
  describe ".new" do
    describe "foaf" do
      subject { RDF::RDFa::Context.new("http://example/") }
      
      it "has a URI" do
        expect(subject.uri).to eq RDF::URI("http://example/")
      end
      
      it "has no terms" do
        expect(subject.terms).to be_empty
      end
      
      it "has no vocabulary" do
        expect(subject.vocabulary).to be_nil
      end
      
      it "has no prefixes" do
        expect(subject.prefixes).to be_empty
      end
    end
  end
  
  describe ".find" do
    describe "rdfa-1.1" do
      subject { RDF::RDFa::Context.find("http://www.w3.org/2011/rdfa-context/rdfa-1.1") }

      it "has 3 terms" do
        expect(subject.terms.keys.length).to eq 3
      end
      
      it "uses symbols for term lookup" do
        expect(subject.terms.keys).to be_all {|k| k.is_a?(Symbol)}
      end

      it "has no vocabulary" do
        expect(subject.vocabulary).to be_nil
      end

      it "has at least 10 prefixes" do
        expect(subject.prefixes.keys.length).to be >= 10
      end
    end

    describe "html+rdfa-1.1" do
      subject { RDF::RDFa::Context.find("http://www.w3.org/2011/rdfa-context/html-rdfa-1.1") }

      it "has 0 terms" do
        expect(subject.terms.keys).to be_empty
      end

      it "has no vocabulary" do
        expect(subject.vocabulary).to be_nil
      end

      it "has no prefixes" do
        expect(subject.prefixes.keys).to be_empty
      end

      it "uses symbols for prefix lookup" do
        expect(subject.prefixes.keys).to be_all {|k| k.is_a?(Symbol)}
      end
    end

    describe "xhtml+rdfa-1.1" do
      subject { RDF::RDFa::Context.find("http://www.w3.org/2011/rdfa-context/xhtml-rdfa-1.1") }

      it "has 25 terms" do
        expect(subject.terms.keys.length).to eq 25
      end

      it "has no vocabulary" do
        expect(subject.vocabulary).to be_nil
      end

      it "has no prefixes" do
        expect(subject.prefixes.keys).to be_empty
      end

      it "uses symbols for prefix lookup" do
        expect(subject.prefixes.keys).to be_all {|k| k.is_a?(Symbol)}
      end
    end
  end
end
