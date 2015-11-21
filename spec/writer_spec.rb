$:.unshift "."
require 'spec_helper'
require 'rdf/xsd'
require 'rdf/spec/writer'
require 'rspec/matchers'

class EX < RDF::Vocabulary("http://example/"); end

describe RDF::RDFa::Writer do
  let(:logger) {RDF::Spec.logger}
  it_behaves_like 'an RDF::Writer' do
    let(:writer) {RDF::RDFa::Writer.new(StringIO.new)}
  end

  before(:each) do
    @graph = RDF::Repository.new
  end
  
  describe ".for" do
    formats = [
      :rdfa,
      'etc/doap.html',
      {file_name:      'etc/doap.html'},
      {file_extension: 'html'},
      {content_type:   'text/html'},

      :xhtml,
      'etc/doap.xhtml',
      {file_name:      'etc/doap.xhtml'},
      {file_extension: 'xhtml'},
      {content_type:   'application/xhtml+xml'},

      :svg,
      'etc/doap.svg',
      {file_name:      'etc/doap.svg'},
      {file_extension: 'svg'},
      {content_type:   'image/svg+xml'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        expect(RDF::Writer.for(arg)).to eq RDF::RDFa::Writer
      end
    end
  end

  describe "#buffer" do
    context "prefix definitions" do
      subject do
        @graph << [EX.a, RDF::Vocab::DC.title, "foo"]
        serialize(prefixes: {dc: "http://purl.org/dc/terms/"})
      end

      specify { expect(subject).to have_xpath("/html/@prefix", %r(dc: http://purl.org/dc/terms/), logger)}
      specify { expect(subject).to have_xpath("/html/@prefix", %r(ex: http://example/), logger)}
      specify { expect(subject).to have_xpath("/html/@prefix", %r(ex:), logger)}
    end

    context "plain literal" do
      subject do
        @graph << [EX.a, EX.b, "foo"]
        serialize(haml_options: {ugly: false})
      end

      {
        "/html/body/div/@resource" => "ex:a",
        "//div[@class='property']/span[@property]/@property" => "ex:b",
        "//div[@class='property']/span[@property]/text()" => "foo",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          expect(subject).to have_xpath(path, value, logger)
        end
      end
    end

    context "dc:title" do
      subject do
        @graph << [EX.a, RDF::Vocab::DC.title, "foo"]
        serialize(prefixes: {dc: RDF::Vocab::DC.to_s})
      end

      {
        "/html/head/title/text()" => "foo",
        "/html/body/div/@resource" => "ex:a",
        "/html/body/div/h1/@property" => "dc:title",
        "/html/body/div/h1/text()" => "foo",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          expect(subject).to have_xpath(path, value, logger)
        end
      end
    end

    context "typed resources" do
      context "typed resource" do
        subject do
          @graph << [EX.a, RDF.type, EX.Type]
          serialize(haml_options: {ugly: false})
        end

        {
          "/html/body/div/@resource" => "ex:a",
          "/html/body/div/@typeof" => "ex:Type",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, logger)
          end
        end
      end

      context "resource with two types" do
        subject do
          @graph << [EX.a, RDF.type, EX.t1]
          @graph << [EX.a, RDF.type, EX.t2]
          serialize(haml_options: {ugly: false})
        end

        {
          "/html/body/div/@resource" => "ex:a",
          "/html/body/div/@typeof" => "ex:t1 ex:t2",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, logger)
          end
        end
      end
    end

    context "languaged tagged literals" do
      context "literal with language and no default language" do
        subject do
          @graph << [EX.a, RDF::Vocab::DC.title, RDF::Literal("foo", language: :en)]
          serialize(prefixes: {dc: "http://purl.org/dc/terms/"})
        end

        {
          "/html/body/div/h1/@property" => "dc:title",
          "/html/body/div/h1/@lang" => "en",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, logger)
          end
        end
      end

      context "literal with language and same default language" do
        subject do
          @graph << [EX.a, RDF::Vocab::DC.title, RDF::Literal("foo", language: :en)]
          serialize(lang: :en)
        end

        {
          "/html/@lang" => "en",
          "/html/body/div/h1/@lang" => false,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, logger)
          end
        end
      end

      context "literal with language and different default language" do
        subject do
          @graph << [EX.a, RDF::Vocab::DC.title, RDF::Literal("foo", language: :en)]
          serialize(lang: :de)
        end

        {
          "/html/@lang" => "de",
          "/html/body/div/h1/@lang" => "en",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, logger)
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
          "/html/body/div/div/ul/li[@property='rdf:value']/text()" => "foo",
          "/html/body/div/div/ul/li/a[@property='rdf:value']/@href" => EX.b.to_s,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, logger)
          end
        end
      end
    end

    context "typed literals" do
      describe "xsd:date" do
        {
          "2011-03-18" => {
            "//span[@property]/@property" => "ex:b",
            "//span[@property]/@datatype" => "xsd:date",
            "//span[@property]/@content" => "2011-03-18",
            "//span[@property]/text()" => "Friday, 18 March 2011",
          },
          "2011-03-18Z" => {
            "//span[@property]/@property" => "ex:b",
            "//span[@property]/@datatype" => "xsd:date",
            "//span[@property]/@content" => "2011-03-18Z",
            "//span[@property]/text()" => "Friday, 18 March 2011 UTC",
          },
          "2011-03-18-08:00" => {
            "//span[@property]/@property" => "ex:b",
            "//span[@property]/@datatype" => "xsd:date",
            "//span[@property]/@content" => "2011-03-18-08:00",
            "//span[@property]/text()" => "Friday, 18 March 2011 -08:00",
          },
        }.each do |v, matches|
          context v do
            subject {
              @graph << [EX.a, EX.b, RDF::Literal::Date.new(v)]
              serialize(haml_options: {ugly: false})
            }
            matches.each do |path, value|
              it "returns #{value.inspect} for xpath #{path}" do
                expect(subject).to have_xpath(path, value, logger)
              end
            end
          end
        end
      end

      context "xsd:time" do
        {
          "12:34:56" => {
            "//span[@property]/@property" => "ex:b",
            "//span[@property]/@datatype" => "xsd:time",
            "//span[@property]/@content" => "12:34:56",
            "//span[@property]/text()" => "12:34:56 PM",
          },
          "12:34:56Z" => {
            "//span[@property]/@property" => "ex:b",
            "//span[@property]/@datatype" => "xsd:time",
            "//span[@property]/@content" => "12:34:56Z",
            "//span[@property]/text()" => "12:34:56 PM UTC",
          },
          "12:34:56-08:00" => {
            "//span[@property]/@property" => "ex:b",
            "//span[@property]/@datatype" => "xsd:time",
            "//span[@property]/@content" => "12:34:56-08:00",
            "//span[@property]/text()" => "12:34:56 PM -08:00",
          },
        }.each do |v, matches|
          context v do
            subject {
              @graph << [EX.a, EX.b, RDF::Literal::Time.new(v)]
              serialize(haml_options: {ugly: false})
            }
            matches.each do |path, value|
              it "returns #{value.inspect} for xpath #{path}" do
                expect(subject).to have_xpath(path, value, logger)
              end
            end
          end
        end
      end

      context "xsd:dateTime" do
        {
          "2011-03-18T12:34:56" => {
            "//span[@property]/@property" => "ex:b",
            "//span[@property]/@datatype" => "xsd:dateTime",
            "//span[@property]/@content" => "2011-03-18T12:34:56",
            "//span[@property]/text()" => "12:34:56 PM on Friday, 18 March 2011",
          },
          "2011-03-18T12:34:56Z" => {
            "//span[@property]/@property" => "ex:b",
            "//span[@property]/@datatype" => "xsd:dateTime",
            "//span[@property]/@content" => "2011-03-18T12:34:56Z",
            "//span[@property]/text()" => "12:34:56 PM UTC on Friday, 18 March 2011",
          },
          "2011-03-18T12:34:56-08:00" => {
            "//span[@property]/@property" => "ex:b",
            "//span[@property]/@datatype" => "xsd:dateTime",
            "//span[@property]/@content" => "2011-03-18T12:34:56-08:00",
            "//span[@property]/text()" => "12:34:56 PM -08:00 on Friday, 18 March 2011",
          },
        }.each do |v, matches|
          context v do
            subject {
              @graph << [EX.a, EX.b, RDF::Literal::DateTime.new(v)]
              serialize(haml_options: {ugly: false})
            }
            matches.each do |path, value|
              it "returns #{value.inspect} for xpath #{path}" do
                expect(subject).to have_xpath(path, value, logger)
              end
            end
          end
        end
      end

      context "rdf:XMLLiteral" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::XML.new("E = mc<sup>2</sup>: The Most Urgent Problem of Our Time")]
          serialize(haml_options: {ugly: false})
        end

        {
          "//span[@property]/@property" => "ex:b",
          "//span[@property]/@datatype" => "rdf:XMLLiteral",
          "//span[@property]" => %r(<span [^>]+>E = mc<sup>2</sup>: The Most Urgent Problem of Our Time<\/span>),
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, logger)
          end
        end
      end
      
      context "xsd:string" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal.new("Albert Einstein", datatype: RDF::XSD.string)]
          serialize(haml_options: {ugly: false})
        end

        {
          "//span[@property]/@property" => "ex:b",
          "//span[@property]/@datatype" => false, # xsd:string implied in RDF 1.1
          "//span[@property]/text()" => "Albert Einstein",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, logger)
          end
        end
      end
      
      context "unknown" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal.new("Albert Einstein", datatype: EX.unknown)]
          serialize(haml_options: {ugly: false})
        end

        {
          "//span[@property]/@property" => "ex:b",
          "//span[@property]/@datatype" => "ex:unknown",
          "//span[@property]/text()" => "Albert Einstein",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, logger)
          end
        end
      end
    end
    
    context "multi-valued literals" do
      subject do
        @graph << [EX.a, EX.b, "c"]
        @graph << [EX.a, EX.b, "d"]
        serialize(haml_options: {ugly: false})
      end

      {
        "//ul/li[1][@property='ex:b']/text()" => "c",
        "//ul/li[2][@property='ex:b']/text()" => "d",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          expect(subject).to have_xpath(path, value, logger)
        end
      end
    end
    
    context "resource objects" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        serialize(haml_options: {ugly: false})
      end

      {
        "//div/@resource" => "ex:a",
        "//a/@property" => "ex:b",
        "//a/@href" => EX.c.to_s,
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          expect(subject).to have_xpath(path, value, logger)
        end
      end
    end
    
    context "multi-valued resource objects" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        @graph << [EX.a, EX.b, EX.d]
        serialize(haml_options: {ugly: false})
      end

      {
        "//div/@resource" => "ex:a",
        "//ul/li[1]/a[@property='ex:b']/@href" => EX.c.to_s,
        "//ul/li[2]/a[@property='ex:b']/@href" => EX.d.to_s,
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          expect(subject).to have_xpath(path, value, logger)
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
            "//div/span[@inlist]/@rel" => 'rdf:value',
            "//div/span[@inlist]/text()" => false,
          }
        ],
        "literal" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value ("Foo") .
          ),
          {
            "//div/span[@inlist]/@property" => 'rdf:value',
            "//div/span[@inlist]/text()" => 'Foo',
          }
        ],
        "IRI" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value (<foo>) .
          ),
          {
            "//div/a[@inlist]/@property" => 'rdf:value',
            "//div/a[@inlist]/@href" => 'foo',
          }
        ],
        "implicit list with hetrogenious membership" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value ("Foo" <foo>) .
          ),
          {
            "//ul/li[1][@inlist]/@property" => 'rdf:value',
            "//ul/li[1][@inlist]/text()" => 'Foo',
            "//ul/li[2]/a[@inlist]/@property" => 'rdf:value',
            "//ul/li[2]/a[@inlist]/@href" => 'foo',
          }
        ],
        "property with list and literal" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value ("Foo" "Bar"), "Baz" .
          ),
          {
            "//div[@class='property']/span[@property='rdf:value']/text()" => "Baz",
            "//div[@class='property']/ul/li[1][@inlist][@property='rdf:value']/text()" => 'Foo',
            "//div[@class='property']/ul/li[2][@inlist][@property='rdf:value']/text()" => 'Bar',
          }
        ],
        "multiple rel items" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <> rdf:value (<foo> <bar>) .
          ),
          {
            "//div[@class='property']/ul/li[1]/a[@inlist][@property='rdf:value']/@href" => 'foo',
            "//div[@class='property']/ul/li[2]/a[@inlist][@property='rdf:value']/@href" => 'bar',
          }
        ],
        "multiple collections" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
            
            <foo> rdf:value ("Foo"), ("Bar") .
          ),
          {
            "//div[@class='property']/ul/li[1][@inlist][@property='rdf:value']/text()" => 'Foo',
            "//div[@class='property']/ul/li[2][@inlist][@property='rdf:value']/text()" => 'Bar',
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
            "//div[@class='property']/ul/li[1][@inlist][@rel='rdf:value']/h1[@property='rdfs:label']/text()" => 'one',
            "//div[@class='property']/ul/li[2][@inlist][@rel='rdf:value']/h1[@property='rdfs:label']/text()" => 'two',
            "//div[@class='property']/ul/li[3][@inlist][@rel='rdf:value']/h1[@property='rdfs:label']/text()" => 'three',
          }
        ]
      }.each do |test, (input, result)|
        it test do
          pending("Serializing multiple lists") if test == "multiple collections"
          skip "REXML" if test == 'issue 14' && !Module.constants.include?(:Nokogiri)
          @graph = parse(input, format: :ttl)
          html = serialize(haml_options: {ugly: false})
          result.each do |path, value|
            expect(html).to have_xpath(path, value, logger)
          end
        end
      end
    end

    context "included resource definitions" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        @graph << [EX.c, EX.d, EX.e]
        serialize(haml_options: {ugly: false})
      end

      {
        "/html/body/div/@resource" => "ex:a",
        "//div[@resource='ex:a']/div[@class='property']/div[@rel]/@rel" => "ex:b",
        "//div[@rel]/@resource" => "ex:c",
        "//div[@rel]/div[@class='property']/a/@href" => EX.e.to_s,
        "//div[@rel]/div[@class='property']/a/@property" => "ex:d",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          expect(subject).to have_xpath(path, value, logger)
        end
      end
    end
  end


  # W3C Test suite from http://www.w3.org/2006/07/SWD/RDFa/testsuite/
  describe "w3c xhtml testcases" do
    require 'suite_helper'

    # Generate with each template set
    RDF::RDFa::Writer::HAML_TEMPLATES.each do |name, template|
      next if name == :distiller && !Module.constants.include?(:Nokogiri)
      context "Using #{name} template" do
        Fixtures::TestCase.for_specific("html5", "rdfa1.1", Fixtures::TestCase::Test.required) do |t|
          next if %w(0140 0198 0225 0284 0295 0319 0329).include?(t.num)
          specify "test #{t.num}: #{t.description}" do
            unless Module.constants.include?(:Nokogiri)
              if %w(0261).include?(t.num)
                pending "REXML"
              end
            end
            input = t.input("html5", "rdfa1.1")
            @graph = RDF::Repository.load(t.input("html5", "rdfa1.1"), logger: false)
            result = serialize(haml: template, haml_options: {ugly: false})
            logger.info result.force_encoding("utf-8")
            graph2 = parse(result, format: :rdfa, logger: false)
            # Need to put this in to avoid problems with added markup
            statements = graph2.query(object: RDF::URI("http://rdf.kellogg-assoc.com/css/distiller.css")).to_a
            statements.each {|st| graph2.delete(st)}
            #puts graph2.dump(:ttl)
            expect(graph2).to be_equivalent_graph(@graph, logger: logger)
          end
        end
      end
    end
  end unless ENV['CI'] # Not for continuous integration

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
    result = RDF::RDFa::Writer.buffer({logger: logger, standard_prefixes: true}.merge(options)) do |writer|
      writer << @graph
    end
    require 'cgi'
    #puts CGI.escapeHTML(result) if $verbose
    result
  end
end
