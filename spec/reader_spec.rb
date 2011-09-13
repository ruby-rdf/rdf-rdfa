$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

describe "RDF::RDFa::Reader" do
  before :each do
    @reader = RDF::RDFa::Reader.new(StringIO.new("<html></html>"))
  end

  it_should_behave_like RDF_Reader

  describe ".for" do
    formats = [
      :rdfa,
      'etc/doap.html',
      {:file_name      => 'etc/doap.html'},
      {:file_extension => 'html'},
      {:content_type   => 'text/html'},

      :xhtml,
      'etc/doap.xhtml',
      {:file_name      => 'etc/doap.xhtml'},
      {:file_extension => 'xhtml'},
      {:content_type   => 'application/xhtml+xml'},

      :svg,
      'etc/doap.svg',
      {:file_name      => 'etc/doap.svg'},
      {:file_extension => 'svg'},
      {:content_type   => 'image/svg+xml'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        RDF::Reader.for(arg).should == RDF::RDFa::Reader
      end
    end
  end

  context :interface do
    before(:each) do
      @sampledoc = %(<?xml version="1.0" encoding="UTF-8"?>
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
        )
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

  context "sanity checking" do
    context "simple doc" do
      before :each do
        sampledoc = %(<?xml version="1.0" encoding="UTF-8"?>
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
          )

        @graph = parse(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0001.xhtml", :validate => true)
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
  end

  context :features do
    describe "XML Literal" do
      before :each do
        sampledoc = %(<?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
          <html xmlns="http://www.w3.org/1999/xhtml"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <head>
              <title>Test 0011</title>
            </head>
            <body>
              <div about="">
                Author: <span property="dc:creator">Albert Einstein</span>
                <h2 property="dc:title" datatype="rdf:XMLLiteral">E = mc<sup>2</sup>: The Most Urgent Problem of Our Time</h2>
            </div>
            </body>
          </html>
          )

        @graph = parse(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml", :validate => true)
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
        begin
          @graph.should have_triple([
            RDF::URI('http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml'),
            RDF::DC11.title,
            RDF::Literal(%(E = mc<sup xmlns="http://www.w3.org/1999/xhtml" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">2</sup>: The Most Urgent Problem of Our Time), :datatype => RDF.XMLLiteral)
          ])
        rescue RSpec::Expectations::ExpectationNotMetError => e
          pending("XMLLiteral canonicalization not implemented yet")
        end
      end
    end

    describe "bnodes" do
      before :each do
        sampledoc = %(<?xml version="1.0" encoding="UTF-8"?>
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
          )

        @graph = parse(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0017.xhtml", :validate => true)
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

    describe "typeof" do
      before :each do
        sampledoc = %(<?xml version="1.0" encoding="UTF-8"?>
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
          )

        @graph = parse(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0049.xhtml", :validate => true)
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
      
      context "empty @typeof on root" do
        before(:all) do
          @sampledoc = %(
            <div typeof><span property="dc:title">Title</span></div>
          )
        end

        it "does not create node" do
          parse(@sampledoc).first_subject.should be_uri
        end
      end
    end

    describe "html>head>base" do
      before :each do
        sampledoc = %(<?xml version="1.0" encoding="UTF-8"?>
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
          )

        @graph = parse(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0072.xhtml", :validate => true)
      end

      it "should return 1 triple" do
        @graph.size.should == 1
      end

      it "should have the subject of the triple relative to the URI in base" do
        @graph.should have_subject RDF::URI('http://www.example.org/faq')
      end
    end

    context "malformed datatypes" do
      {
        "xsd:boolean" => %w(foo),
        "xsd:date" => %w(+2010-01-01Z 2010-01-01TFOO 02010-01-01 2010-1-1 0000-01-01 2011-07 2011),
        "xsd:dateTime" => %w(+2010-01-01T00:00:00Z 2010-01-01T00:00:00FOO 02010-01-01T00:00:00 2010-01-01 2010-1-1T00:00:00 0000-01-01T00:00:00 2011-07 2011),
        "xsd:decimal" => %w(12.xyz),
        "xsd:double" => %w(xy.z +1.0z),
        "xsd:integer" => %w(+1.0z foo),
        "xsd:time" => %w(+00:00:00Z -00:00:00Z 00:00 00),
      }.each do |dt, values|
        context dt do
          values.each do |value|
            before(:all) do
              @rdfa = %(<span about="" property="rdf:value" datatype="#{dt}" content="#{value}"/>)
              dt_uri = RDF::XSD.send(dt.split(':').last)
              @expected = RDF::Graph.new << RDF::Statement.new(RDF::URI(""), RDF.value, RDF::Literal.new(value, :datatype => dt_uri))
            end

            context "with #{value}" do
              it "creates triple with invalid literal" do
                parse(@rdfa, :validate => false).should be_equivalent_graph(@expected)
              end
            
              it "does not create triple when validating" do
                lambda {parse(@rdfa, :validate => true)}.should raise_error(RDF::ReaderError)
              end
            end
          end
        end
      end
    end

    context "@vocab" do
      before (:all) do
        @sampledoc = %q(
        <html>
          <head>
            <base href="http://example.org/"/>
          </head>
          <body>
            <div about ="#me" vocab="http://xmlns.com/foaf/0.1/" typeof="Person" >
              <p property="name">Gregg Kellogg</p>
            </div>
          </body>
        </html>
        )
      end
      
      it "uses vocabulary when creating property IRI" do
        query = %q(
          PREFIX foaf: <http://xmlns.com/foaf/0.1/>
          ASK WHERE { <http://example.org/#me> a foaf:Person }
        )
        parse(@sampledoc).should pass_query(query, @debug)
      end

      it "uses vocabulary when creating type IRI" do
        query = %q(
          PREFIX foaf: <http://xmlns.com/foaf/0.1/>
          ASK WHERE { <http://example.org/#me> foaf:name "Gregg Kellogg" }
        )
        parse(@sampledoc).should pass_query(query, @debug)
      end

      it "adds rdfa:hasProperty triple" do
        query = %q(
          PREFIX foaf: <http://xmlns.com/foaf/0.1/>
          PREFIX rdfa: <http://www.w3.org/ns/rdfa#>
          ASK WHERE { <http://example.org/> rdfa:hasVocabulary foaf: }
        )
        parse(@sampledoc).should pass_query(query, @debug)
      end
    end

    context "collections" do
      {
        "empty list" => [
          %q(
            <div about ="">
              <p rel="rdf:value" resource="rdf:nil"/>
            </div>
          ),
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value () .
          )
        ],
        "literal" => [
          %q(
            <div about ="">
              <p property="rdf:value" member="">Foo</p>
            </div>
          ),
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value ("Foo") .
          )
        ],
        "IRI" => [
          %q(
            <div about ="">
              <a rel="rdf:value" member="" href="foo">Foo</a>
            </div>
          ),
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value (<foo>) .
          )
        ],
        "implicit list with hetrogenious membership" => [
          %q(
            <div about ="">
              <p property="rdf:value" member="">Foo</p>
              <a rel="rdf:value" member="" href="foo">Foo</p>
            </div>
          ),
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value ("Foo" <foo>) .
          )
        ],
        "implicit list at different levels" => [
          %q(
            <div about ="">
              <p property="rdf:value" member="">Foo</p>
              <strong><p property="rdf:value" member="">Bar</p></strong>
            </div>
          ),
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value ("Foo" "Bar") .
          )
        ],
        "property with list and literal" => [
          %q(
            <div about ="">
              <p property="rdf:value" member="">Foo</p>
              <strong><p property="rdf:value" member="">Bar</p></strong>
              <p property="rdf:value">Baz</p>
            </div>
          ),
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value ("Foo" "Bar"), "Baz" .
          )
        ],
        "multiple rel items" => [
          %q(
            <div about ="">
              <ol rel="rdf:value" member="">
                <li><a href="foo">Foo</a></li>
                <li><a href="bar">Bar</a></li>
              </ol
            </div>
          ),
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value (<foo> <bar>) .
          )
        ],
        "multiple collections" => [
          %q(
            <div>
              <div about ="foo">
                <p property="rdf:value" member="">Foo</p>
              </div>
              <div about="foo">
                <p property="rdf:value" member="">Bar</p>
              </div>
            </div>
          ),
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <foo> rdf:value ("Foo"), ("Bar") .
          )
        ],
        "confusion between multiple implicit collections (resource)" => [
          %q(
            <div about ="">
              <p property="rdf:value" member="">Foo</p>
              <span rel="rdf:member" resource="res">
                <p property="rdf:value" member="">Bar</p>
              </span>
            </div>
          ),
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value ("Foo"); rdf:member <res> .
            <res> rdf:value ("Bar") .
          )
        ],
        "confusion between multiple implicit collections (about)" => [
          %q(
            <div about ="">
              <p property="rdf:value" member="">Foo</p>
              <span rel="rdf:member">
                <p about="res" property="rdf:value" member="">Bar</p>
              </span>
            </div>
          ),
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value ("Foo"); rdf:member <res> .
            <res> rdf:value ("Bar") .
          )
        ],
      }.each do |test, (input, result)|
        it test do
          parse(input).should be_equivalent_graph(result, :trace => @debug, :format => :ttl)
        end
      end
    end
  end

  context "problematic examples" do
    it "parses Jeni's Ice Cream example" do
      sampledoc = %q(<root><div vocab="#" typeof="">
        <p>Flavors in my favorite ice cream:</p>
        <div rel="flavor">
          <ul vocab="http://www.w3.org/1999/02/22-rdf-syntax-ns#" typeof="">
            <li property="first">Lemon sorbet</li>
            <li rel="rest">
              <span typeof="">
                <span property="first">Apricot sorbet</span>
              <span rel="rest" resource="rdf:nil"></span>
            </span>
            </li>
          </ul>
        </div>
      </div></root>)
      ttl = %q(
      <> <http://www.w3.org/ns/rdfa#hasVocabulary> <#>, <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      _:a <#flavor> ("Lemon sorbet" "Apricot sorbet") .
      )
      g_ttl = RDF::Graph.new << RDF::Turtle::Reader.new(ttl)
      parse(sampledoc, :validate => false).should be_equivalent_graph(g_ttl)
    end
  end

  context :validation do
  end

  def parse(input, options = {})
    @debug = options[:debug] || []
    graph = RDF::Graph.new
    RDF::RDFa::Reader.new(input, options.merge(:debug => @debug)).each do |statement|
      graph << statement
    end
    graph
  end

end
