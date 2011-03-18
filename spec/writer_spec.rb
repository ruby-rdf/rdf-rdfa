$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/writer'
require 'rspec/matchers'

class EX < RDF::Vocabulary("http://example/"); end

describe RDF::RDFa::Writer do
  before(:each) do
    @graph = RDF::Graph.new
    @writer = RDF::RDFa::Writer
  end
  
  it_should_behave_like RDF_Writer
  
  describe "#buffer" do
    context "with base" do
    end

    describe "prefix definitions" do
      subject do
        @graph << [EX.a, RDF::DC.title, "foo"]
        serialize
      end

      {
        "/xhtml:html/@prefix" => %r(dc: http://purl.org/dc/terms/),
        "/xhtml:html/@prefix" => %r(ex: http://example/),
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value)
        end
      end
    end
    
    describe "plain literal" do
      subject do
        @graph << [EX.a, EX.b, "foo"]
        serialize
      end

      {
        "/xhtml:html/xhtml:body/xhtml:div/@about" => "ex:a",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@property" => "ex:b",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/text()" => "foo",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value)
        end
      end
    end

    describe "dc:title" do
      subject do
        @graph << [EX.a, RDF::DC.title, "foo"]
        serialize
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
      describe "typed resource" do
        subject do
          @graph << [EX.a, RDF.type, EX.Type]
          serialize
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

      describe "resource with two types" do
        subject do
          @graph << [EX.a, RDF.type, EX.t1]
          @graph << [EX.a, RDF.type, EX.t2]
          serialize
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
      describe "literal with language and no default language" do
        subject do
          @graph << [EX.a, RDF::DC.title, RDF::Literal("foo", :language => :en)]
          serialize
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

      describe "literal with language and same default language" do
        subject do
          @graph << [EX.a, RDF::DC.title, RDF::Literal("foo", :language => :en)]
          serialize(:lang => :en)
        end

        {
          "/xhtml:html/@lang" => "en",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:h1/@property" => "dc:title",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:h1/@lang" => false,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value)
          end
        end
      end

      describe "literal with language and different default language" do
        subject do
          @graph << [EX.a, RDF::DC.title, RDF::Literal("foo", :language => :en)]
          serialize(:lang => :de)
        end

        {
          "/xhtml:html/@lang" => "de",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:h1/@property" => "dc:title",
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
          serialize
        end

        {
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@property" => "ex:b",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@datatype" => "xsd:date",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@content" => "2011-03-18",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/text()" => "Friday, 18 March 2011",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value)
          end
        end
      end

      describe "xsd:time" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::Time.new("12:34:56")]
          serialize
        end

        {
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@property" => "ex:b",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@datatype" => "xsd:time",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@content" => "12:34:56",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/text()" => /12:34:56/,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value)
          end
        end
      end

      describe "xsd:dateTime" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::DateTime.new("2011-03-18T12:34:56")]
          serialize
        end

        {
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@property" => "ex:b",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@datatype" => "xsd:dateTime",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@content" => "2011-03-18T12:34:56",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/text()" => /12:34:56 \w+ on Friday, 18 March 2011/,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value)
          end
        end
      end

      describe "rdf:XMLLiteral" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::XML.new("E = mc<sup>2</sup>: The Most Urgent Problem of Our Time")]
          serialize
        end

        {
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@property" => "ex:b",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@datatype" => "rdf:XMLLiteral",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span" => %r(<span [^>]+>E = mc<sup>2</sup>: The Most Urgent Problem of Our Time<\/span>),
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value)
          end
        end
      end
      
      describe "xsd:string" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal.new("Albert Einstein", :datatype => RDF::XSD.string)]
          serialize
        end

        {
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@property" => "ex:b",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@datatype" => "xsd:string",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/text()" => "Albert Einstein",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value)
          end
        end
      end
      
      describe "unknown" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal.new("Albert Einstein", :datatype => EX.unknown)]
          serialize
        end

        {
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@property" => "ex:b",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/@datatype" => "ex:unknown",
          "/xhtml:html/xhtml:body/xhtml:div/xhtml:span/text()" => "Albert Einstein",
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
        serialize
      end

      {
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:ul/@property" => "ex:b",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:ul/xhtml:li[1]/text()" => "c",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:ul/xhtml:li[2]/text()" => "d",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value)
        end
      end
    end
    
    context "resource objects" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        serialize
      end

      {
        "/xhtml:html/xhtml:body/xhtml:div/@about" => "ex:a",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:a/@rel" => "ex:b",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:a/@href" => EX.c.to_s,
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
        serialize
      end

      {
        "/xhtml:html/xhtml:body/xhtml:div/@about" => "ex:a",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:ul/@rel" => "ex:b",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:ul/xhtml:li[1]/@about" => "ex:c",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:ul/xhtml:li[2]/@about" => "ex:d",
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
        serialize
      end

      {
        "/xhtml:html/xhtml:body/xhtml:div/@about" => "ex:a",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:ul/@rel" => "ex:b",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:ul/xhtml:li/@about" => "ex:c",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:ul/xhtml:li/xhtml:a/@rel" => "ex:d",
        "/xhtml:html/xhtml:body/xhtml:div/xhtml:ul/xhtml:li/xhtml:a/@href" => EX.e.to_s,
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value)
        end
      end
    end

    require 'rdfa_helper'
    def self.test_cases
      RdfaHelper::TestCase.test_cases("xhtml")
    end

    # W3C Test suite from http://www.w3.org/2006/07/SWD/RDFa/testsuite/
    describe "w3c xhtml testcases" do
      test_cases.each do |t|
        next unless t.classification =~ /required/ && t.expectedResults
        next if t.name == "0212"  # XMLLiteral equivalence
        specify "test #{t.name}: #{t.title}" do
          @graph = parse(t.input, :base_uri => t.informationResourceInput, :format => :rdfa)
          result = serialize
          graph2 = parse(result, :format => :rdfa)
          graph2.should be_equivalent_graph(@graph, :trace => @debug.unshift(result).join("\n"))
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
    result = @writer.buffer({:debug => @debug, :standard_prefixes => true}.merge(options)) do |writer|
      writer << @graph
    end
    require 'cgi'
    puts CGI.escapeHTML(result) if $verbose
    result
  end
end
