$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdfa_helper'

describe RDF::RDFa::Format do
  it "should be discoverable" do
    formats = [
      RDF::Format.for(:rdfa),
      RDF::Format.for("etc/foaf.html"),
      RDF::Format.for(:file_name      => "etc/foaf.html"),
      RDF::Format.for(:file_extension => "html"),
      RDF::Format.for(:file_extension => "xhtml"),
      RDF::Format.for(:content_type   => "text/html"),
      RDF::Format.for(:content_type   => "application/xhtml+xml"),
    ]
    formats.each { |format| format.should == RDF::RDFa::Format }
  end
end

describe "RDF::RDFa::Reader" do
  before(:all) do
    # Don't load external profiles when testing
    {
      "basic" => {
        :base_uri => "http://www.w3.org/2007/08/pyRdfa/profiles/basic",
        :format => :rdfa,
        :file => File.join(File.dirname(__FILE__), "..", "etc", "basic.html"),
      },
      "foaf" => {
        :base_uri => "http://www.w3.org/2007/08/pyRdfa/profiles/foaf",
        :format => :rdfa,
        :file => File.join(File.dirname(__FILE__), "..", "etc", "foaf.html"),
      },
      "xhv" => {
        :base_uri => "http://www.w3.org/1999/xhtml/vocab",
        :format => :rdfa,
        :file => File.join(File.dirname(__FILE__), "..", "etc", "xhv.html"),
      },
      "profile" => {
        :base_uri => "http://www.w3.org/2005/10/profile",
        :format => :rdfa,
        :value => "PROFILE",
      },
      "hcard" => {
        :base_uri => "http://microformats.org/profiles/hcard",
        :format => :rdfa,
        :value => "HCARD",
      },
    }.each_pair do |name, opts|
      if opts[:file]
        graph = RDF::Graph.new
        RDF::Reader.for(opts[:format]).new(File.read(opts[:file]),
                    :base_uri => opts[:base_uri]).each do |statement|
          graph << statement
        end
        opts[:value] = graph
      end
      RDF::Graph.stub!(:load).with(opts[:base_uri],
                      :base_uri => opts[:base_uri],
                      :format => opts[:format]).and_return(opts[:value])
    end
  end
  
  context "discovery" do
    {
      "html" => RDF::Reader.for(:rdfa),
      "etc/foaf.html" => RDF::Reader.for("etc/foaf.html"),
      "foaf.html" => RDF::Reader.for(:file_name      => "foaf.html"),
      ".html" => RDF::Reader.for(:file_extension => "html"),
      "application/xhtml+xml" => RDF::Reader.for(:content_type   => "application/xhtml+xml"),
    }.each_pair do |label, format|
      it "should discover '#{label}'" do
        format.should == RDF::RDFa::Reader
      end
    end
  end

  context :interface do
    before(:each) do
      @sampledoc = <<-EOF;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:dc="http://purl.org/dc/elements/1.1/">
<head>
  <title>Test 0001</title>
</head>
<body>
  <p>This photo was taken by <span class="author" about="photo1.jpg" property="dc:creator">Mark Birbeck</span>.</p>
</body>
</html>
EOF
    end

    it "should yield reader" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::RDFa::Reader)
      RDF::RDFa::Reader.new(@sampledoc) do |reader|
        inner.called(reader.class)
      end
    end

    it "should return reader" do
      RDF::RDFa::Reader.new(@sampledoc).should be_a(RDF::RDFa::Reader)
    end

    it "should yield statements" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::Statement)
      RDF::RDFa::Reader.new(@sampledoc).each_statement do |statement|
        inner.called(statement.class)
      end
    end

    it "should yield triples" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::URI, RDF::URI, RDF::Literal)
      RDF::RDFa::Reader.new(@sampledoc).each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
  end

  context "paring a simple doc" do
    before :each do
      sampledoc = <<-EOF;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:dc="http://purl.org/dc/elements/1.1/">
<head>
  <title>Test 0001</title>
</head>
<body>
  <p>This photo was taken by <span class="author" about="photo1.jpg" property="dc:creator">Mark Birbeck</span>.</p>
</body>
</html>
EOF

      @graph = parse(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0001.xhtml", :strict => true)
      @statement = @graph.statements.first
    end

    it "should return 1 triple" do
      @graph.size.should == 1
    end

    it "should have a subject with an expanded URI" do
      @statement.subject.should == RDF::URI('http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/photo1.jpg')
    end

    it "should have a predicate of dc:creator" do
      @statement.predicate.should == RDF::DC11.creator
    end

    it "should have an object of type literal and value 'Mark Birkbeck'" do
      @statement.object.should == RDF::Literal("Mark Birbeck")
    end
  end

  context "parsing a simple doc without a base URI" do
    before :each do
      sampledoc = <<-EOF;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:dc="http://purl.org/dc/elements/1.1/">
<body>
  <p>This photo was taken by <span class="author" about="_:photo" property="dc:creator">Mark Birbeck</span>.</p>
</body>
</html>
EOF

      @graph = parse(sampledoc, :strict => true)
      @statement = @graph.statements.first
    end

    it "should return 1 triple" do
      @graph.size.should == 1
    end

    it "should have a Blank Node named 'photo' as the subject of the triple" do
      @statement.subject.should == RDF::Node('photo')
    end

    it "should have a predicate of dc:creator" do
      @statement.predicate.should == RDF::DC11.creator
    end

    it "should have an object of type literal and value 'Mark Birkbeck'" do
      @statement.object.should == RDF::Literal("Mark Birbeck")
    end
  end

  context "parsing a document containing an XML Literal" do
    before :each do
      sampledoc = <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:dc="http://purl.org/dc/elements/1.1/">
  <head>
    <title>Test 0011</title>
  </head>
  <body>
    <div about="">
      Author: <span property="dc:creator">Albert Einstein</span>
      <h2 property="dc:title">E = mc<sup>2</sup>: The Most Urgent Problem of Our Time</h2>
  </div>
  </body>
</html>
EOF

      @graph = parse(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml", :strict => true)
    end

    it "should return 2 triples" do
      @graph.size.should == 2
    end

    it "should have a triple for the dc:creator of the document" do
      @graph.should have_triple([
        RDF::URI('http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml'),
        RDF::DC11.creator,
        "Albert Einstein"
      ])
    end

    it "should have an XML Literal for the dc:title of the document" do
      @graph.should have_triple([
        RDF::URI('http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml'),
        RDF::DC11.title,
        RDF::Literal("E = mc<sup xmlns=\"http://www.w3.org/1999/xhtml\">2</sup>: The Most Urgent Problem of Our Time", :datatype => RDF.XMLLiteral)
      ])
    end
  end

  context "parsing a document containing sereral bnodes" do
    before :each do
      sampledoc = <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.1"
      xmlns:foaf="http://xmlns.com/foaf/0.1/">
  <head>
  <title>Test 0017</title>
  </head>
  <body>
     <p>
          <span about="[_:a]" property="foaf:name">Manu Sporny</span>
           <span about="[_:a]" rel="foaf:knows" resource="[_:b]">knows</span>
           <span about="[_:b]" property="foaf:name">Ralph Swick</span>.
        </p>
  </body>
</html>
EOF

      @graph = parse(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0017.xhtml", :strict => true)
    end

    it "should return 3 triples" do
      @graph.size.should == 3
    end

    it "should have a triple for the foaf:name of BNode A" do
      @graph.should have_triple([
        RDF::Node('a'),
        RDF::FOAF.name,
        "Manu Sporny"
      ])
    end

    it "should have a triple for the foaf:name of BNode B" do
      @graph.should have_triple([
        RDF::Node('b'),
        RDF::FOAF.name,
        "Ralph Swick"
      ])
    end

    it "should have a triple for BNode A knows BNode B" do
      @graph.should have_triple([
        RDF::Node('a'),
        RDF::FOAF.knows,
        RDF::Node('b'),
      ])
    end
  end

  context "parsing a document that uses the typeof attribute" do
    before :each do
      sampledoc = <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.1"
      xmlns:foaf="http://xmlns.com/foaf/0.1/">
  <head>
    <title>Test 0049</title>
  </head>
  <body>
    <div about="http://www.example.org/#me" typeof="foaf:Person">
      <p property="foaf:name">John Doe</p>
    </div>
  </body>
</html>
EOF

      @graph = parse(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0049.xhtml", :strict => true)
    end

    it "should return 2 triples" do
      @graph.size.should == 2
    end

    it "should have a triple stating that #me is of type foaf:Person" do
      @graph.should have_triple([
        RDF::URI('http://www.example.org/#me'),
        RDF.type,
        RDF::FOAF.Person
      ])
    end

    it "should have a triple stating that #me has name 'John Doe'" do
      @graph.should have_triple([
        RDF::URI('http://www.example.org/#me'),
        RDF::FOAF.name,
        RDF::Literal("John Doe")
      ])
    end
  end

  context "parsing a document with a <base> tag in the <head>" do
    before :each do
      sampledoc = <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.1"
    xmlns:dc="http://purl.org/dc/elements/1.1/">
 <head>
    <base href="http://www.example.org/"></base>
    <title>Test 0072</title>
 </head>
 <body>
    <p about="faq">
       Learn more by reading the example.org
       <span property="dc:title">Example FAQ</span>.
    </p>
 </body>
</html>
EOF

      @graph = parse(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0072.xhtml", :strict => true)
    end

    it "should return 1 triple" do
      @graph.size.should == 1
    end

    it "should have the subject of the triple relative to the URI in base" do
      @graph.should have_subject RDF::URI('http://www.example.org/faq')
    end
  end

  context "parsing a document with a profile containing a prefix mapping" do
    before :each do
      sampledoc = <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.1">
  <head>
    <title>Test</title>
    <base href="http://example.org/"/>
  </head>
  <body profile="http://www.w3.org/2007/08/pyRdfa/profiles/basic">
  <div about="#me">
    <p>
      <span property="foaf:name">Ivan Herman</span>
    </p>
  </div>
  </body>
</html>
EOF
      
      @graph = parse(sampledoc, :strict => true)
      @statement = @graph.statements.first
    end

    it "should return 1 triple" do
      @graph.size.should == 1
    end

    it "should have a subject of http://example.org/#me" do
      @statement.subject.should == RDF::URI('http://example.org/#me')
    end

    it "should have a predicate of foaf:name" do
      @statement.predicate.should == RDF::FOAF.name
    end

    it "should have an object with the literal 'Ivan Herman'" do
      @statement.object.should == RDF::Literal('Ivan Herman')
    end
  end

  context "parsing a document with a profile containing a term mapping" do
    before :each do
      sampledoc = <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.1">
  <head>
    <title>Test</title>
    <base href="http://example.org/"/>
  </head>
  <body profile="http://www.w3.org/2007/08/pyRdfa/profiles/foaf">
  <div about="#me">
    <p>
      <span property="name">Ivan Herman</span>
    </p>
  </div>
  </body>
</html>
EOF
      
      @graph = parse(sampledoc, :strict => true)
      @statement = @graph.statements.first
    end

    it "should return 1 triple" do
      @graph.size.should == 1
    end

    it "should have a subject of http://example.org/#me" do
      @statement.subject.should == RDF::URI('http://example.org/#me')
    end

    it "should have a predicate of foaf:name" do
      @statement.predicate.should == RDF::FOAF.name
    end

    it "should have an object with the literal 'Ivan Herman'" do
      @statement.object.should == RDF::Literal('Ivan Herman')
    end
  end

  def self.test_cases(suite)
    RdfaHelper::TestCase.test_cases(suite)
  end

  # W3C Test suite from http://www.w3.org/2006/07/SWD/RDFa/testsuite/
  %w(xhtml xhtml11).each do |suite| # html4 html5
    describe "w3c #{suite} testcases" do
      describe "that are approved" do
        test_cases(suite).each do |t|
          next unless t.status == "approved"
          #next unless t.name =~ /0001/
          specify "test #{t.name}: #{t.title}#{",  (negative test)" unless t.expectedResults}" do
            #puts t.input
            #puts t.results
            begin
              t.run_test do |rdfa_string|
                t.debug = []
                parse(rdfa_string,
                    :base_uri => t.informationResourceInput,
                    :debug => t.debug)
              end
            rescue SparqlException => e
              pending(e.message) { raise }
            end
          end
        end
      end
      describe "that are unreviewed" do
        test_cases(suite).each do |t|
          next unless t.status == "unreviewed"
          #next unless t.name =~ /0185/
          #puts t.inspect
          specify "test #{t.name}: #{t.title}#{",  (negative test)" unless t.expectedResults}" do
            begin
              t.run_test do |rdfa_string|
                t.debug = []
                parse(rdfa_string,
                    :base_uri => t.informationResourceInput,
                    :debug => t.debug)
              end
            rescue SparqlException => e
              pending(e.message) { raise }
            rescue Spec::Expectations::ExpectationNotMetError => e
              if t.name =~ /01[789]\d/
                raise
              else
                pending() {  raise }
              end
            end
          end
        end
      end
   end
 end

  def parse(input, options)
    @debug = options[:debug] || []
    graph = RDF::Graph.new
    RDF::RDFa::Reader.new(input, options.merge(:debug => @debug)).each do |statement|
      graph << statement
    end
    graph
  end

end
