$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')

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
    describe "foaf" do
      subject { RDF::RDFa::Profile.find("http://rdfa.digitalbazaar.com/test-suite/profiles/foaf") }

      it "has 74 terms" do
        subject.terms.keys.length.should == 74
      end
      
      it "uses symbols for term lookup" do
        subject.terms.keys.all? {|k| k.is_a?(Symbol)}.should be_true
      end

      it "has no vocabulary" do
        subject.vocabulary.should be_nil
      end

      it "has no prefixes" do
        subject.prefixes.should be_empty
      end
    end

    describe "basic" do
      subject { RDF::RDFa::Profile.find("http://rdfa.digitalbazaar.com/test-suite/profiles/basic") }

      it "has no terms" do
        subject.terms.should be_empty
      end

      it "has no vocabulary" do
        subject.vocabulary.should be_nil
      end

      it "has 6 prefixes" do
        subject.prefixes.keys.length.should == 6
      end

      it "uses symbols for prefix lookup" do
        subject.prefixes.keys.all? {|k| k.is_a?(Symbol)}.should be_true
      end
    end
  end
end
