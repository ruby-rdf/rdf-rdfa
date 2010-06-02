require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDFa::Reader::Namespace do
  subject { RDFa::Reader::Namespace.new("http://xmlns.com/foaf/0.1/", "foaf") }

  describe "method_missing" do
    it "should create URI" do
      subject.knows.to_s.should == "http://xmlns.com/foaf/0.1/knows"
    end
    
    it "should create URI for frag" do
      foaf_frag = RDFa::Reader::Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
      foaf_frag.knows.to_s.should == "http://xmlns.com/foaf/0.1/knows"
    end
  end
  
  it "should have a URI" do
    lambda do
      test = RDFa::Reader::Namespace.new(prefix='foaf')
    end.should raise_error
  end
  
  it "should have equality with URIs" do
    foaf_name = RDF::URI.new("http://xmlns.com/foaf/0.1/name")
    subject.name.should == foaf_name
  end
  
  it "should have an XML and N3-friendly prefix" do
    lambda do
      test = RDFa::Reader::Namespace.new('http://xmlns.com/foaf/0.1/', '*~{')
    end.should raise_error
  end
  
#   it "should be able to attach to the graph for substitution" do
#     # rdflib does this using graph.bind('prefix', namespace)
#     g = RDF::Graph.new
#     subject.bind(g)
#     #puts g.nsbinding.inspect
#     should == g.nsbinding["foaf"]
#   end
  
  it "should not allow you to attach to non-graphs" do
    lambda do
      subject.bind("cheese")
    end.should raise_error
  end
  
  it "should construct URI" do
    subject.foo.class.should == RDF::URI
    subject.foo.to_s.should == "http://xmlns.com/foaf/0.1/foo"
  end
  
  describe "no URI normalization" do
    specify {RDFa::Reader::Namespace.new("http://foo", "foo").uri.to_s.should == "http://foo"}
    specify {RDFa::Reader::Namespace.new("http://foo#", "foo").uri.to_s.should == "http://foo#"}
    specify {RDFa::Reader::Namespace.new("http://foo/", "foo").uri.to_s.should == "http://foo/"}
    specify {RDFa::Reader::Namespace.new("xyz:foo", "foo").uri.to_s.should == "xyz:foo"}
  end
  
  it "should not normalize URI" do
  end
  
  describe "serialization" do
    specify {subject.to_s.should == "foaf: http://xmlns.com/foaf/0.1/"}
  end

  describe '#+' do
    it "should construct URI with +" do
      (subject + "foo").class.should == RDF::URI
      (subject + "foo").to_s.should == "http://xmlns.com/foaf/0.1/foo"
    end
    
    it "should strip trailing _ (used to work around reserved method names)" do
      (subject + "type_").to_s.should == "http://xmlns.com/foaf/0.1/type"
    end
    
    it "will cause method conflict" do
      (subject + "class").to_s.should == "http://xmlns.com/foaf/0.1/class"
      subject.class.should ==  RDFa::Reader::Namespace
    end
  end
  
  describe "normalization" do
    {
      %w(http://foo ) =>  "http://foo",
      %w(http://foo a) => "http://fooa",

      %w(http://foo/ ) =>  "http://foo/",
      %w(http://foo/ a) => "http://foo/a",

      %w(http://foo# ) =>  "http://foo#",
      %w(http://foo# a) => "http://foo#a",

      %w(http://foo/bar ) =>  "http://foo/bar",
      %w(http://foo/bar a) => "http://foo/bara",

      %w(http://foo/bar/ ) =>  "http://foo/bar/",
      %w(http://foo/bar/ a) => "http://foo/bar/a",

      %w(http://foo/bar# ) =>  "http://foo/bar#",
      %w(http://foo/bar# a) => "http://foo/bar#a",
    }.each_pair do |input, result|
      it "should create <#{result}> from <#{input[0]}> and '#{input[1]}'" do
        (RDFa::Reader::Namespace.new(input[0], "test") + input[1].to_s).to_s.should == result
      end
    end
  end

  it "should be be equivalent" do
    RDFa::Reader::Namespace.new("http://a", "aa").should == RDFa::Reader::Namespace.new("http://a", "aa")
  end
end
