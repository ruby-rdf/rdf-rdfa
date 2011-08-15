$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDF::RDFa::Format do
  context "should discover 'rdfa'" do
    [
      [:rdfa,                                        RDF::RDFa::Format],
      ["etc/foaf.html",                              RDF::RDFa::Format],
      [{:file_name      => "etc/foaf.html"},         RDF::RDFa::Format],
      [{:file_extension => "html"},                  RDF::RDFa::Format],
      [{:file_extension => "xhtml"},                 RDF::RDFa::XHTML],
      [{:file_extension => "svg"},                   RDF::RDFa::SVG],
      [{:content_type   => "text/html"},             RDF::RDFa::Format],
      [{:content_type   => "application/xhtml+xml"}, RDF::RDFa::XHTML],
      [{:content_type   => "image/svg+xml"},         RDF::RDFa::SVG],
    ].each do |(arg, format)|
      it "returns #{format} for #{arg.inspect}" do
        RDF::Format.for(arg).should == format
      end
    end
  end
    
  it "should discover 'html'" do
    RDF::Format.for(:html).reader.should == RDF::RDFa::Reader
    RDF::Format.for(:html).writer.should == RDF::RDFa::Writer
  end

  it "should discover 'xhtml'" do
    RDF::Format.for(:xhtml).reader.should == RDF::RDFa::Reader
    RDF::Format.for(:xhtml).writer.should == RDF::RDFa::Writer
  end

  it "should discover 'svg'" do
    RDF::Format.for(:svg).reader.should == RDF::RDFa::Reader
    RDF::Format.for(:svg).writer.should == RDF::RDFa::Writer
  end
end

describe "RDF::RDFa::Reader" do
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
      
      context "empty @typeof" do
        before(:all) do
          @sampledoc = %(
            <div typeof><span property="dc:title">Title</span></div>
          )
        end

        it "does not create node with XML host language" do
          parse(@sampledoc, :host_language => :xml1).first_subject.should be_uri
        end
      
        it "creates a node with HTML host language" do
          parse(@sampledoc, :host_language => :html5).first_subject.should be_node
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

    context :profile do
      describe "prefix" do
        before :each do
          sampledoc = %(<?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
            <html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.1">
              <head>
                <title>Test</title>
                <base href="http://example.org/"/>
              </head>
              <body profile="http://rdfa.digitalbazaar.com/test-suite/test-cases/tests/../../profiles/basic">
              <div about="#me">
                <p>
                  <span property="foaf:name">Ivan Herman</span>
                </p>
              </div>
              </body>
            </html>
            )

          @graph = parse(sampledoc, :validate => true)
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

      describe "term" do
        before :each do
          sampledoc = %(<?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
            <html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.1">
              <head>
                <title>Test</title>
                <base href="http://example.org/"/>
              </head>
              <body profile="http://rdfa.digitalbazaar.com/test-suite/test-cases/tests/../../profiles/foaf">
              <div about="#me">
                <p>
                  <span property="name">Ivan Herman</span>
                </p>
              </div>
              </body>
            </html>
          )

          @graph = parse(sampledoc, :validate => true)
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

      describe :parsing do
        before(:each) do
          @profile = StringIO.new(%q(<?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml">
              <head>
                <title>Test mappings</title>
              </head>
              <body prefix="rdfa: http://www.w3.org/ns/rdfa#">
                <p typeof=""><span property="rdfa:uri">http://example.org/</span><span property="rdfa:prefix">foo</span></p>
                <p typeof=""><span property="rdfa:uri">http://example.org/title</span><span property="rdfa:term">title</span></p>
              </body>
            </html>
          ))
          def @profile.content_type; "text/html"; end
          def @profile.base_uri; "http://example.com/profile"; end

          @doc = %(<?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml">
              <body profile="http://example.com/profile">
                <div about="http://example.com/doc" typeof="foo:Agent">
                  <p property="title">A particular agent</p>
                </div>
              </body>
            </html>
            )

          RDF::Util::File.stub!(:open_file).and_yield(@profile)

          @profile_repository = RDF::Repository.new(:title => "Test Profile Repository")
          @debug = []
          @reader = RDF::RDFa::Reader.new(@doc, :profile_repository => @profile_repository, :debug => @debug, :validate => true)

          @expected = RDF::Graph.new
          @expected << [RDF::URI("http://example.com/doc"), RDF.type, RDF::URI("http://example.org/Agent")]
          @expected << [RDF::URI("http://example.com/doc"), RDF::URI("http://example.org/title"), "A particular agent"]
        end

        it "parses profile" do
          RDF::Reader.should_receive(:for).at_least(1).times.and_return(RDF::RDFa::Reader)
          g = RDF::Graph.load(@profile)
          g.count.should == 4
        end

        describe "new profile" do
          subject do
            # Clear vocabulary cache
            RDF::RDFa::Profile.cache.send(:initialize)
            RDF::Graph.new << @reader
          end

          it "matches expected" do
            subject.should be_equivalent_graph(@expected, :trace => @debug.join("\n"))
          end
        end

        describe "cached profile" do
          before(:each) do
            # Clear vocabulary cache
            RDF::RDFa::Profile.cache.send(:initialize)
            @reader.each {|s|}
          end

          it "should not re-parse profile" do
            RDF::RDFa::Profile.cache.send(:initialize)
            RDF::Reader.should_not_receive(:open).with("http://example.com/profile")
            RDF::RDFa::Reader.new(@doc, :profile_repository => @profile_repository).each {|p|}
          end

          it "should create vocab_cache" do
            RDF::RDFa::Profile.cache.should be_a(RDF::Util::Cache)
          end
        end

        describe "profile content" do
          before(:each) do
            bn_p = RDF::Node.new("prefix")
            bn_t = RDF::Node.new("term")
            ctx = RDF::URI("http://example.com/profile")
            @profile_repository << RDF::Statement.new(bn_p, RDF::RDFA.prefix, RDF::Literal.new("foo"), :context => ctx)
            @profile_repository << RDF::Statement.new(bn_p, RDF::RDFA.uri, RDF::Literal.new("http://example.org/"), :context => ctx)
            @profile_repository << RDF::Statement.new(bn_t, RDF::RDFA.term, RDF::Literal.new("title"), :context => ctx)
            @profile_repository << RDF::Statement.new(bn_t, RDF::RDFA.uri, RDF::Literal.new("http://example.org/title"), :context => ctx)

            # Clear vocabulary cache
            RDF::RDFa::Profile.cache.send(:initialize)
          end

          it "should not recieve RDF::Reader.open" do
            RDF::Reader.should_not_receive(:open).with("http://example.com/profile")
            @reader.each {|s|}
          end

          it "matches expected" do
            graph = RDF::Graph.new << @reader
            graph.should be_equivalent_graph(@expected, :trace => @debug.join("\n"))
          end
        end
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
  end

  context "problematic examples" do
    it "parses Jeni's Ice Cream example" do
      sampledoc = %q(<div vocab="#" typeof="">
        <p>Flavors in my favorite ice cream:</p>
        <div rel="flavor">
          <ul vocab="http://www.w3.org/1999/02/22-rdf-syntax-ns#" typeof="List">
            <li property="first">Lemon sorbet</li>
            <li rel="rest">
              <span typeof="List">
                <span property="first">Apricot sorbet</span>
              <span rel="rest" resource="rdf:nil"></span>
            </span>
            </li>
          </ul>
        </div>
      </div>)
      nt = %q(
      _:a <#flavor> _:b .
      _:b <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "Lemon sorbet" .
      _:b <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:c .
      _:b <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#List> .
      _:c <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "Apricot sorbet" .
      _:c <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
      _:c <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#List> .
      )
      parse(sampledoc, :validate => false).should be_equivalent_graph(nt)
    end
  end

  context :validation do
  end

  # W3C Test suite from http://www.w3.org/2006/07/SWD/RDFa/testsuite/
  describe "w3c test cases" do
    require 'test_helper'
    
    Fixtures::TestCase::HOST_LANGUAGE_VERSION_SETS.each do |(host_language, version)|
      describe "for #{host_language} #{version}" do
        %w(required optional buggy).each do |classification|
          describe "that are #{classification}" do
            Fixtures::TestCase.for_specific(host_language, version, Fixtures::TestCase::Test.send(classification)) do |t|
              specify "test #{t.name}: #{t.title}#{",  (negative test)" if t.expectedResults.false?}" do
                begin
                  t.debug = []
                  reader = RDF::Reader.open(t.input(host_language, version),
                    :base_uri => t.input(host_language, version),
                    :debug => t.debug,
                    :format => :rdfa)
                  reader.should be_a RDF::Reader

                  # Make sure auto-detect works
                  unless host_language =~ /svg/ || t.name == "0216" # due to http-equiv
                    reader.host_language.should == host_language.to_sym
                    reader.version.should == version.to_sym
                  end

                  graph = RDF::Graph.new << reader
                  query = Kernel.open(t.results(host_language, version))
                  graph.should pass_query(query, t)
                rescue RSpec::Expectations::ExpectationNotMetError => e
                  if %w(0198).include?(t.name) || query =~ /XMLLiteral/m
                    pending("XMLLiteral canonicalization not implemented yet")
                  elsif classification != "required"
                    pending("#{classification} test") {  raise }
                  else
                    raise
                  end
                end
              end
            end
          end
        end
      end
    end
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
