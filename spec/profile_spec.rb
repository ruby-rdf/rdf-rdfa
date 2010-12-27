$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDF::RDFa::Profile do
  describe ".new" do
    describe "foaf" do
      subject { RDF::RDFa::Profile.new("http://rdfa.digitalbazaar.com/test-suite/profiles/foaf") }
      
      it "has 74 terms" do
        subject.terms.keys.length.should == 74
      end
      
      it "has no vocabulary" do
        subject.vocabulary.should be_nil
      end
      
      it "has no prefixes" do
        subject.prefixes.should be_empty
      end
    end

    describe "basic" do
      subject { RDF::RDFa::Profile.new("http://rdfa.digitalbazaar.com/test-suite/profiles/basic") }
      
      it "has no terms" do
        subject.terms.should be_empty
      end
      
      it "has no vocabulary" do
        subject.vocabulary.should be_nil
      end
      
      it "has 6 prefixes" do
        subject.prefixes.keys.length.should == 6
      end
    end
  end
  
  describe ".find" do
    before(:all) do
      RDF::RDFa::Profile.find("http://rdfa.digitalbazaar.com/test-suite/profiles/basic")
      RDF::RDFa::Profile.find("http://rdfa.digitalbazaar.com/test-suite/profiles/foaf")
    end
    
    it "cached basic" do
      RDF::RDFa::Profile.cache[RDF::URI.intern("http://rdfa.digitalbazaar.com/test-suite/profiles/basic")].should be_a(RDF::RDFa::Profile)
    end
    
    it "cached foaf" do
      RDF::RDFa::Profile.cache[RDF::URI.intern("http://rdfa.digitalbazaar.com/test-suite/profiles/foaf")].should be_a(RDF::RDFa::Profile)
    end
  end
end
