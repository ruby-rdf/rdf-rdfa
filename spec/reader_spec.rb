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

  [:nokogiri, :rexml].each do |library|
    context library.to_s, :library => library do
      next if library == :nokogiri && RUBY_PLATFORM == 'java'
      before(:all) {@library = library}
      
      context "sanity checking" do
        it "simple doc" do
          html = %(<?xml version="1.0" encoding="UTF-8"?>
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
          expected = %(
            @prefix dc: <http://purl.org/dc/elements/1.1/> .

            <photo1.jpg> dc:creator "Mark Birbeck" .
          )

          parse(html, :validate => true).should be_equivalent_graph(expected, :trace => @debug)
        end
      end

      context :features do
        describe "XML Literal" do
          it "xmlns=" do
            html = %(<?xml version="1.0" encoding="UTF-8"?>
              <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
              <html xmlns="http://www.w3.org/1999/xhtml">
                <head><base href=""/></head>
                <body>
                  <div about="http://example.com/">
                    <h2 property="dc:title" datatype="rdf:XMLLiteral">E = mc<sup>2</sup>: The Most Urgent Problem of Our Time</h2>
                </div>
                </body>
              </html>
              )
            expected = %q(
              @base <http://example.com/> .
              @prefix dc: <http://purl.org/dc/terms/> .
              @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

              <> dc:title "E = mc<sup xmlns=\"http://www.w3.org/1999/xhtml\">2</sup>: The Most Urgent Problem of Our Time"^^rdf:XMLLiteral .
            )

            parse(html).should be_equivalent_graph(expected, :trace => @debug)
          end
        end

        it "bnodes" do
          html = %(<?xml version="1.0" encoding="UTF-8"?>
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
          expected = %q(
            @base <http://example.com> .
            @prefix foaf: <http://xmlns.com/foaf/0.1/> .

             [ foaf:name "Manu Sporny";
               foaf:knows [ foaf:name "Ralph Swick"];
             ] .
          )

          parse(html, :validate => true).should be_equivalent_graph(expected, :trace => @debug)
        end

        describe "@about" do
          it "creates a statement with subject from @about" do
            html = %(
              <span about="foo" property="dc:title">Title</span>
            )
            expected = RDF::Graph.new << RDF::Statement.new(RDF::URI("foo"), RDF::DC.title, "Title")
            parse(html).should be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
          end
        end

        describe "@resource" do
          it "creates a statement with object from @resource" do
            html = %(
              <div about="foo"><span resource="bar" rel="rdf:value"/></div>
            )
            expected = RDF::Graph.new << RDF::Statement.new(RDF::URI("foo"), RDF.value, RDF::URI("bar"))
            parse(html).should be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
          end

          it "uses @resource as subject of child elements" do
            html = %(
              <div resource="foo"><span property="dc:title">Title</span></div>
            )
            expected = RDF::Graph.new << RDF::Statement.new(RDF::URI("foo"), RDF::DC.title, "Title")
            parse(html).should be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
          end
        end

        describe "@href" do
          it "creates a statement with object from @href" do
            html = %(
              <div about="foo"><a href="bar" rel="rdf:value"></a></div>
            )
            expected = RDF::Graph.new << RDF::Statement.new(RDF::URI("foo"), RDF.value, RDF::URI("bar"))
            parse(html).should be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
          end
        end

        describe "@src" do
          subject {
            %(
              <div about="foo" xmlns:dc="http://purl.org/dc/terms/">
                <img src="bar" rel="rdf:value" property="dc:title" content="Title"/>
              </div>
            )
          }
          context "RDFa 1.0" do
            it "creates a statement with subject from @src" do
              expected = RDF::Graph.new << RDF::Statement.new(RDF::URI("bar"), RDF::DC.title, "Title")
              parse(subject, :version => "rdfa1.0").should be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
            end
          end
      
          context "RDFa 1.1" do
            it "creates a statement with object from @src" do
              expected = RDF::Graph.new <<
                RDF::Statement.new(RDF::URI("foo"), RDF.value, RDF::URI("bar")) <<
                RDF::Statement.new(RDF::URI("foo"), RDF::DC.title, "Title")
              parse(subject).should be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
            end
          end
        end

        describe "@typeof" do
          it "handles basic case" do
            html = %(<?xml version="1.0" encoding="UTF-8"?>
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
            expected = %(
              @prefix foaf: <http://xmlns.com/foaf/0.1/> .
              @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

              <http://www.example.org/#me> a foaf:Person;
                 foaf:name "John Doe" .
            )

            parse(html, :validate => true).should be_equivalent_graph(expected, :trace => @debug)
          end
          
          it "empty @typeof on root" do
            html = %(<div typeof=""><span property="dc:title">Title</span></div>)
            expected = RDF::Graph.new << RDF::Statement.new(RDF::URI(""), RDF::DC.title, "Title")

            parse(html).should be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
          end
        end

        it "html>head>base" do
          html = %(<?xml version="1.0" encoding="UTF-8"?>
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
          expected = %q(
            @prefix dc: <http://purl.org/dc/elements/1.1/> .

            <http://www.example.org/faq> dc:title "Example FAQ" .
          )

          parse(html).should be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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
                    parse(@rdfa, :validate => false).should be_equivalent_graph(@expected, :trace => @debug)
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
          before(:all) do
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

        context "lists" do
          {
            "empty list" => [
              %q(
                <div about="">
                  <p rel="rdf:value" inlist=""/>
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
                <div about="">
                  <p property="rdf:value" inlist="">Foo</p>
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
                <div about="">
                  <a rel="rdf:value" inlist="" href="foo">Foo</a>
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
                <div about="">
                  <p property="rdf:value" inlist="">Foo</p>
                  <a rel="rdf:value" inlist="" href="foo">Foo</a>
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
                <div about="">
                  <p property="rdf:value" inlist="">Foo</p>
                  <strong><p property="rdf:value" inlist="">Bar</p></strong>
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
                <div about="">
                  <p property="rdf:value" inlist="">Foo</p>
                  <strong><p property="rdf:value" inlist="">Bar</p></strong>
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
                <div about="">
                  <ol rel="rdf:value" inlist="">
                    <li><a href="foo">Foo</a></li>
                    <li><a href="bar">Bar</a></li>
                  </ol>
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
                  <div about="foo">
                    <p property="rdf:value" inlist="">Foo</p>
                  </div>
                  <div about="foo">
                    <p property="rdf:value" inlist="">Bar</p>
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
                <div about="">
                  <p property="rdf:value" inlist="">Foo</p>
                  <span rel="rdf:inlist" resource="res">
                    <p property="rdf:value" inlist="">Bar</p>
                  </span>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
                <> rdf:value ("Foo"); rdf:inlist <res> .
                <res> rdf:value ("Bar") .
              )
            ],
            "confusion between multiple implicit collections (about)" => [
              %q(
                <div about="">
                  <p property="rdf:value" inlist="">Foo</p>
                  <span rel="rdf:inlist">
                    <p about="res" property="rdf:value" inlist="">Bar</p>
                  </span>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
                <> rdf:value ("Foo"); rdf:inlist <res> .
                <res> rdf:value ("Bar") .
              )
            ],
          }.each do |test, (input, expected)|
            it test do
              parse(input).should be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
            end
          end
        end
      end

      context "problematic examples" do
        it "parses Jeni's Ice Cream example" do
          html = %q(<root><div vocab="#" typeof="">
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
          parse(html, :validate => false).should be_equivalent_graph(g_ttl, :trace => @debug, :format => :ttl)
        end
      end

      context :validation do
      end
    end
  end

  def parse(input, options = {})
    @debug = options[:debug] || []
    graph = RDF::Graph.new
    RDF::RDFa::Reader.new(input, options.merge(:debug => @debug, :library => @library)).each do |statement|
      graph << statement rescue fail "SPEC: #{$!}"
    end
    graph
  end

end
