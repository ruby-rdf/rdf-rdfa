$:.unshift "."
require 'spec_helper'

describe RDF::RDFa::Profile do
  describe ".new" do
    describe "foaf" do
      subject { RDF::RDFa::Profile.new("http://example/") }
      
      it "has a URI" do
        subject.uri.should == RDF::URI("http://example/")
      end
      
      it "has no terms" do
        subject.terms.should be_empty
      end
      
      it "has no vocabulary" do
        subject.vocabulary.should be_nil
      end
      
      it "has no prefixes" do
        subject.prefixes.should be_empty
      end
    end
  end
  
  describe ".find" do
    describe "rdfa-1.1" do
      subject { RDF::RDFa::Profile.find("http://www.w3.org/2011/rdfa-context/rdfa-1.1") }

      it "has 3 terms" do
        subject.terms.keys.length.should == 3
      end
      
      it "uses symbols for term lookup" do
        subject.terms.keys.all? {|k| k.is_a?(Symbol)}.should be_true
      end

      it "has no vocabulary" do
        subject.vocabulary.should be_nil
      end

      it "has 27 prefixes" do
        subject.prefixes.keys.length.should == 27
      end
    end

    describe "html+rdfa-1.1" do
      subject { RDF::RDFa::Profile.find("http://www.w3.org/2011/rdfa-context/html-rdfa-1.1") }

      it "has 0 terms" do
        subject.terms.keys.length.should == 0
      end

      it "has no vocabulary" do
        subject.vocabulary.should be_nil
      end

      it "has 0 prefixes" do
        subject.prefixes.keys.length.should == 0
      end

      it "uses symbols for prefix lookup" do
        subject.prefixes.keys.all? {|k| k.is_a?(Symbol)}.should be_true
      end
    end

    describe "xhtml+rdfa-1.1" do
      subject { RDF::RDFa::Profile.find("http://www.w3.org/2011/rdfa-context/xhtml-rdfa-1.1") }

      it "has 25 terms" do
        subject.terms.keys.length.should == 25
      end

      it "has no vocabulary" do
        subject.vocabulary.should be_nil
      end

      it "has 0 prefixes" do
        subject.prefixes.keys.length.should == 0
      end

      it "uses symbols for prefix lookup" do
        subject.prefixes.keys.all? {|k| k.is_a?(Symbol)}.should be_true
      end
    end
  end
end
