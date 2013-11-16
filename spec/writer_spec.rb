$:.unshift "."
require 'spec_helper'
require 'rdf/xsd'
require 'rdf/spec/writer'
require 'rspec/matchers'

class EX < RDF::Vocabulary("http://example/"); end

describe RDF::RDFa::Writer do
  before(:each) do
    @graph = RDF::Repository.new
    @writer = RDF::RDFa::Writer.new(StringIO.new)
  end
  
  include RDF_Writer

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
        RDF::Writer.for(arg).should == RDF::RDFa::Writer
      end
    end
  end

  context "generic" do
    before(:each) do
      @writer = RDF::RDFa::Writer.new(StringIO.new)
    end
    #it_should_behave_like RDF_Writer   # This seems to have broken sometime before 2011-07-07
  end
  
  describe "#buffer" do
    context "prefix definitions" do
      subject do
        @graph << [EX.a, RDF::DC.title, "foo"]
        serialize(:prefixes => {:dc => "http://purl.org/dc/terms/"})
      end

      specify { subject.should have_xpath("/xhtml:html/@prefix", %r(dc: http://purl.org/dc/terms/), @debug)}
      specify { subject.should have_xpath("/xhtml:html/@prefix", %r(ex: http://example/), @debug)}
      specify { subject.should have_xpath("/xhtml:html/@prefix", %r(ex:), @debug)}
    end

    context "plain literal" do
      subject do
        @graph << [EX.a, EX.b, "foo"]
        serialize(:haml_options => {:ugly => false})
      end

      {
        "/xhtml:html/xhtml:body/xhtml:div/@resource" => "ex:a",
        "//xhtml:div[@class='property']/xhtml:span[@property]/@property" => "ex:b",
        "//xhtml:div[@class='property']/xhtml:span[@property]/text()" => "foo",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, @debug)
        end
      end
    end

    context "dc:title" do
      subject do
        @graph << [EX.a, RDF::DC.title, "foo"]
        serialize(:prefixes => {:dc => RDF::DC.to_s})
      end

      {
        "/xhtml:html/xhtml:head/xhtml:title/text()" => "foo",
        "/xhtml:html/xhtml:body/xhtml:div/@resource" => "ex:a",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:h1/@property" => "dc:title",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:h1/text()" => "foo",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, @debug)
        end
      end
    end

    context "typed resources" do
      context "typed resource" do
        subject do
          @graph << [EX.a, RDF.type, EX.Type]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "/xhtml:html/xhtml:body/xhtml:div/@resource" => "ex:a",
          "/xhtml:html/xhtml:body/xhtml:div/@typeof" => "ex:Type",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "resource with two types" do
        subject do
          @graph << [EX.a, RDF.type, EX.t1]
          @graph << [EX.a, RDF.type, EX.t2]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "/xhtml:html/xhtml:body/xhtml:div/@resource" => "ex:a",
          "/xhtml:html/xhtml:body/xhtml:div/@typeof" => "ex:t1 ex:t2",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end
    end

    context "languaged tagged literals" do
      context "literal with language and no default language" do
        subject do
          @graph << [EX.a, RDF::DC.title, RDF::Literal("foo", :language => :en)]
          serialize(:prefixes => {:dc => "http://purl.org/dc/terms/"})
        end

        {
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:h1/@property" => "dc:title",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:h1/@lang" => "en",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "literal with language and same default language" do
        subject do
          @graph << [EX.a, RDF::DC.title, RDF::Literal("foo", :language => :en)]
          serialize(:lang => :en)
        end

        {
          "/xhtml:html/@lang" => "en",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:h1/@lang" => false,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "literal with language and different default language" do
        subject do
          @graph << [EX.a, RDF::DC.title, RDF::Literal("foo", :language => :en)]
          serialize(:lang => :de)
        end

        {
          "/xhtml:html/@lang" => "de",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:h1/@lang" => "en",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end
      
      context "property and rel serialize to different elements" do
        subject do
          @graph << [EX.a, RDF.value, "foo"]
          @graph << [EX.a, RDF.value, EX.b]
          serialize
        end

        {
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:div/xhtml:ul/xhtml:li[@property='rdf:value']/text()" => "foo",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:div/xhtml:ul/xhtml:li/xhtml:a[@property='rdf:value']/@href" => EX.b.to_s,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end
    end

    context "typed literals" do
      describe "xsd:date" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::Date.new("2011-03-18")]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "//xhtml:span[@property]/@property" => "ex:b",
          "//xhtml:span[@property]/@datatype" => "xsd:date",
          "//xhtml:span[@property]/@content" => "2011-03-18",
          "//xhtml:span[@property]/text()" => "Friday, 18 March 2011",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "xsd:time" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::Time.new("12:34:56")]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "//xhtml:span[@property]/@property" => "ex:b",
          "//xhtml:span[@property]/@datatype" => "xsd:time",
          "//xhtml:span[@property]/@content" => "12:34:56",
          "//xhtml:span[@property]/text()" => /12:34:56/,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "xsd:dateTime" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::DateTime.new("2011-03-18T12:34:56")]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "//xhtml:span[@property]/@property" => "ex:b",
          "//xhtml:span[@property]/@datatype" => "xsd:dateTime",
          "//xhtml:span[@property]/@content" => "2011-03-18T12:34:56",
          "//xhtml:span[@property]/text()" => /12:34:56 \w+ on Friday, 18 March 2011/,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "rdf:XMLLiteral" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::XML.new("E = mc<sup>2</sup>: The Most Urgent Problem of Our Time")]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "//xhtml:span[@property]/@property" => "ex:b",
          "//xhtml:span[@property]/@datatype" => "rdf:XMLLiteral",
          "//xhtml:span[@property]" => %r(<span [^>]+>E = mc<sup>2</sup>: The Most Urgent Problem of Our Time<\/span>),
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end
      
      context "xsd:string" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal.new("Albert Einstein", :datatype => RDF::XSD.string)]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "//xhtml:span[@property]/@property" => "ex:b",
          "//xhtml:span[@property]/@datatype" => false, # xsd:string implied in RDF 1.1
          "//xhtml:span[@property]/text()" => "Albert Einstein",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end
      
      context "unknown" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal.new("Albert Einstein", :datatype => EX.unknown)]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "//xhtml:span[@property]/@property" => "ex:b",
          "//xhtml:span[@property]/@datatype" => "ex:unknown",
          "//xhtml:span[@property]/text()" => "Albert Einstein",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end
    end
    
    context "multi-valued literals" do
      subject do
        @graph << [EX.a, EX.b, "c"]
        @graph << [EX.a, EX.b, "d"]
        serialize(:haml_options => {:ugly => false})
      end

      {
        "//xhtml:ul/xhtml:li[1][@property='ex:b']/text()" => "c",
        "//xhtml:ul/xhtml:li[2][@property='ex:b']/text()" => "d",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, @debug)
        end
      end
    end
    
    context "resource objects" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        serialize(:haml_options => {:ugly => false})
      end

      {
        "//xhtml:div/@resource" => "ex:a",
        "//xhtml:a/@property" => "ex:b",
        "//xhtml:a/@href" => EX.c.to_s,
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, @debug)
        end
      end
    end
    
    context "multi-valued resource objects" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        @graph << [EX.a, EX.b, EX.d]
        serialize(:haml_options => {:ugly => false})
      end

      {
        "//xhtml:div/@resource" => "ex:a",
        "//xhtml:ul/xhtml:li[1]/xhtml:a[@property='ex:b']/@href" => EX.c.to_s,
        "//xhtml:ul/xhtml:li[2]/xhtml:a[@property='ex:b']/@href" => EX.d.to_s,
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, @debug)
        end
      end
    end
    
    context "lists" do
      {
        "empty list" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value () .
          ),
          {
            "//xhtml:div/xhtml:span[@inlist]/@rel" => 'rdf:value',
            "//xhtml:div/xhtml:span[@inlist]/text()" => false,
          }
        ],
        "literal" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value ("Foo") .
          ),
          {
            "//xhtml:div/xhtml:span[@inlist]/@property" => 'rdf:value',
            "//xhtml:div/xhtml:span[@inlist]/text()" => 'Foo',
          }
        ],
        "IRI" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value (<foo>) .
          ),
          {
            "//xhtml:div/xhtml:a[@inlist]/@property" => 'rdf:value',
            "//xhtml:div/xhtml:a[@inlist]/@href" => 'foo',
          }
        ],
        "implicit list with hetrogenious membership" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value ("Foo" <foo>) .
          ),
          {
            "//xhtml:ul/xhtml:li[1][@inlist]/@property" => 'rdf:value',
            "//xhtml:ul/xhtml:li[1][@inlist]/text()" => 'Foo',
            "//xhtml:ul/xhtml:li[2]/xhtml:a[@inlist]/@property" => 'rdf:value',
            "//xhtml:ul/xhtml:li[2]/xhtml:a[@inlist]/@href" => 'foo',
          }
        ],
        "property with list and literal" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value ("Foo" "Bar"), "Baz" .
          ),
          {
            "//xhtml:div[@class='property']/xhtml:span[@property='rdf:value']/text()" => "Baz",
            "//xhtml:div[@class='property']/xhtml:ul/xhtml:li[1][@inlist][@property='rdf:value']/text()" => 'Foo',
            "//xhtml:div[@class='property']/xhtml:ul/xhtml:li[2][@inlist][@property='rdf:value']/text()" => 'Bar',
          }
        ],
        "multiple rel items" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value (<foo> <bar>) .
          ),
          {
            "//xhtml:div[@class='property']/xhtml:ul/xhtml:li[1]/xhtml:a[@inlist][@property='rdf:value']/@href" => 'foo',
            "//xhtml:div[@class='property']/xhtml:ul/xhtml:li[2]/xhtml:a[@inlist][@property='rdf:value']/@href" => 'bar',
          }
        ],
        "multiple collections" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <foo> rdf:value ("Foo"), ("Bar") .
          ),
          {
            "//xhtml:div[@class='property']/xhtml:ul/xhtml:li[1][@inlist][@property='rdf:value']/text()" => 'Foo',
            "//xhtml:div[@class='property']/xhtml:ul/xhtml:li[2][@inlist][@property='rdf:value']/text()" => 'Bar',
          }
        ],
        "issue 14" => [
          %q(
            @base <http://example/> .
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value (<needs/one> <needs/two> <needs/three>) .
            <needs/one> rdfs:label "one" .
            <needs/three> rdfs:label "three" .
            <needs/two> rdfs:label "two" .
          ),
          {
            "//xhtml:div[@class='property']/xhtml:ul/xhtml:li[1][@inlist][@rel='rdf:value']/text()" => 'one',
            "//xhtml:div[@class='property']/xhtml:ul/xhtml:li[2][@inlist][@rel='rdf:value']/text()" => 'two',
            "//xhtml:div[@class='property']/xhtml:ul/xhtml:li[3][@inlist][@rel='rdf:value']/text()" => 'three',
          }
        ]
      }.each do |test, (input, result)|
        it test do
          pending("Serializing multiple lists") if test == "multiple collections"
          @graph = parse(input, :format => :ttl)
          html = serialize(:haml_options => {:ugly => false})
          result.each do |path, value|
            html.should have_xpath(path, value, @debug)
          end
        end
      end
    end

    context "included resource definitions" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        @graph << [EX.c, EX.d, EX.e]
        serialize(:haml_options => {:ugly => false})
      end

      {
        "/xhtml:html/xhtml:body/xhtml:div/@resource" => "ex:a",
        "//xhtml:div[@resource='ex:a']/xhtml:div[@class='property']/xhtml:div[@rel]/@rel" => "ex:b",
        "//xhtml:div[@rel]/@resource" => "ex:c",
        "//xhtml:div[@rel]/xhtml:div[@class='property']/xhtml:a/@href" => EX.e.to_s,
        "//xhtml:div[@rel]/xhtml:div[@class='property']/xhtml:a/@property" => "ex:d",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, @debug)
        end
      end
    end

    unless ENV['CI'] # Not for continuous integration
      # W3C Test suite from http://www.w3.org/2006/07/SWD/RDFa/testsuite/
      describe "w3c xhtml testcases" do
        require 'suite_helper'

        # Generate with each template set
        RDF::RDFa::Writer::HAML_TEMPLATES.each do |name, template|
          context "Using #{name} template" do
            Fixtures::TestCase.for_specific("html5", "rdfa1.1", Fixtures::TestCase::Test.required) do |t|
              next if %w(0198 0225 0284 0295 0319 0329).include?(t.num)
              specify "test #{t.num}: #{t.description}" do
                input = t.input("html5", "rdfa1.1")
                @graph = RDF::Repository.load(t.input("html5", "rdfa1.1"))
                result = serialize(:haml => template, :haml_options => {:ugly => false})
                graph2 = parse(result, :format => :rdfa)
                # Need to put this in to avoid problems with added markup
                statements = graph2.query(:object => RDF::URI("http://rdf.kellogg-assoc.com/css/distiller.css")).to_a
                statements.each {|st| graph2.delete(st)}
                #puts graph2.dump(:ttl)
                graph2.should be_equivalent_graph(@graph, :trace => @debug.unshift(result.force_encoding("utf-8")).join("\n"))
              end
            end
          end
        end
      end
    end
  end

  require 'rdf/turtle'
  def parse(input, options = {})
    reader_class = RDF::Reader.for(options[:format]) if options[:format]
    reader_class ||= options.fetch(:reader, RDF::Reader.for(detect_format(input)))
  
    graph = RDF::Repository.new
    reader_class.new(input, options).each do |statement|
      graph << statement
    end
    graph
  end

  # Serialize  @graph to a string and compare against regexps
  def serialize(options = {})
    @debug = []
    result = RDF::RDFa::Writer.buffer({:debug => @debug, :standard_prefixes => true}.merge(options)) do |writer|
      writer << @graph
    end
    require 'cgi'
    puts CGI.escapeHTML(result) if $verbose
    result
  end
end
