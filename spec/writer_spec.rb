$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/writer'
require 'rspec/matchers'

class EX < RDF::Vocabulary("http://example/"); end

describe RDF::RDFa::Writer do
  before(:each) do
    @graph = RDF::Graph.new
  end
  
  context "generic" do
    before(:each) do
      @writer = RDF::RDFa::Writer.new(StringIO.new)
    end
    it_should_behave_like RDF_Writer
  end
  
  describe "#buffer" do
    context "prefix definitions" do
      subject do
        @graph << [EX.a, RDF::DC.title, "foo"]
        serialize(:prefixes => {:dc => "http://purl.org/dc/terms/"})
      end

      specify { subject.should have_xpath("/xhtml:html/@prefix", %r(dc: http://purl.org/dc/terms/))}
      specify { subject.should have_xpath("/xhtml:html/@prefix", %r(ex: http://example/))}
      specify { subject.should_not have_xpath("/xhtml:html/@prefix", %r(bibo:))}
    end

    context "plain literal" do
      subject do
        @graph << [EX.a, EX.b, "foo"]
        serialize(:haml_options => {:ugly => false})
      end

      {
        "/xhtml:html/xhtml:body/xhtml:div/@about" => "ex:a",
        "//xhtml:div[@class='property']/xhtml:span[@property]/@property" => "ex:b",
        "//xhtml:div[@class='property']/xhtml:span[@property]/text()" => "foo",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value)
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
        "/xhtml:html/xhtml:body/xhtml:div/@about" => "ex:a",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:h1/@property" => "dc:title",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:h1/text()" => "foo",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value)
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
          "/xhtml:html/xhtml:body/xhtml:div/@about" => "ex:a",
          "/xhtml:html/xhtml:body/xhtml:div/@typeof" => "ex:Type",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value)
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
          "/xhtml:html/xhtml:body/xhtml:div/@about" => "ex:a",
          "/xhtml:html/xhtml:body/xhtml:div/@typeof" => "ex:t1 ex:t2",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value)
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
            subject.should have_xpath(path, value)
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
            subject.should have_xpath(path, value)
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
            subject.should have_xpath(path, value)
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
            subject.should have_xpath(path, value)
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
            subject.should have_xpath(path, value)
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
            subject.should have_xpath(path, value)
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
            subject.should have_xpath(path, value)
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
          "//xhtml:span[@property]/@datatype" => "xsd:string",
          "//xhtml:span[@property]/text()" => "Albert Einstein",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value)
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
            subject.should have_xpath(path, value)
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
        "//xhtml:ul/@property" => "ex:b",
        "//xhtml:ul/xhtml:li[1]/text()" => "c",
        "//xhtml:ul/xhtml:li[2]/text()" => "d",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value)
        end
      end
    end
    
    context "resource objects" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        serialize(:haml_options => {:ugly => false})
      end

      {
        "//xhtml:div/@about" => "ex:a",
        "//xhtml:a/@rel" => "ex:b",
        "//xhtml:a/@href" => EX.c.to_s,
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value)
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
        "//xhtml:div/@about" => "ex:a",
        "//xhtml:ul/@rel" => "ex:b",
        "//xhtml:ul/xhtml:li[1]/xhtml:a/@href" => EX.c.to_s,
        "//xhtml:ul/xhtml:li[2]/xhtml:a/@href" => EX.d.to_s,
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value)
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
        "/xhtml:html/xhtml:body/xhtml:div/@about" => "ex:a",
        "//xhtml:div[@about='ex:a']/xhtml:div[@class='property']/xhtml:div[@rel]/@rel" => "ex:b",
        "//xhtml:div[@rel]/@resource" => "ex:c",
        "//xhtml:div[@rel]/xhtml:div[@class='property']/xhtml:a/@href" => EX.e.to_s,
        "//xhtml:div[@rel]/xhtml:div[@class='property']/xhtml:a/@rel" => "ex:d",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value)
        end
      end
    end

    # W3C Test suite from http://www.w3.org/2006/07/SWD/RDFa/testsuite/
    describe "w3c xhtml testcases" do
      require 'test_helper'

      # Generate with each template set
      RDF::RDFa::Writer::HAML_TEMPLATES.each do |name, template|
        context "Using #{name} template" do
          Fixtures::TestCase.for_specific("xhtml1", "rdfa1.1", Fixtures::TestCase::Test.required) do |t|
            next if t.name == "0212"  # XMLLiteral equivalence
            specify "test #{t.name}: #{t.title}" do
              begin
                input = t.input("xhtml1", "rdfa1.1")
                @graph = RDF::Graph.load(t.input("xhtml1", "rdfa1.1"))
                result = serialize(:haml => template, :haml_options => {:ugly => false})
                graph2 = parse(result, :format => :rdfa)
                graph2.should be_equivalent_graph(@graph, :trace => @debug.unshift(result).join("\n"))
              rescue RSpec::Expectations::ExpectationNotMetError => e
                if %w(0198).include?(t.name) || result =~ /XMLLiteral/m
                  pending("XMLLiteral canonicalization not implemented yet")
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

  require 'rdf/n3'
  def parse(input, options = {})
    reader_class = RDF::Reader.for(options[:format]) if options[:format]
    reader_class ||= options.fetch(:reader, RDF::Reader.for(detect_format(input)))
  
    graph = RDF::Graph.new
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
