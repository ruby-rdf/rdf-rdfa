$:.unshift "."
require 'spec_helper'
require 'rdf/spec/format'

describe RDF::RDFa::Format do
  before :each do
    @format_class = RDF::RDFa::Format
  end

  it_should_behave_like RDF_Format

  describe ".for" do
    formats = [
      :rdfa,
      'etc/doap.html',
      {:file_name      => 'etc/doap.html'},
      {:file_extension => 'html'},
      {:content_type   => 'text/html'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        RDF::Format.for(arg).should == @format_class
      end
    end

    {
      :rdfa   => '<div about="foo"></div>',
    }.each do |sym, str|
      it "detects #{sym}" do
        @format_class.for {str}.should == @format_class
      end
    end

    it "should discover 'html'" do
      RDF::Format.for(:html).reader.should == RDF::RDFa::Reader
      RDF::Format.for(:html).writer.should == RDF::RDFa::Writer
    end

    describe RDF::RDFa::XHTML do
      formats = [
        :xhtml,
        'etc/doap.xhtml',
        {:file_name      => 'etc/doap.xhtml'},
        {:file_extension => 'xhtml'},
        {:content_type   => 'application/xhtml+xml'},
      ].each do |arg|
        it "discovers with #{arg.inspect}" do
          RDF::Format.for(arg).should == RDF::RDFa::XHTML
        end
      end

      it "should discover 'xhtml'" do
        RDF::Format.for(:xhtml).reader.should == RDF::RDFa::Reader
        RDF::Format.for(:xhtml).writer.should == RDF::RDFa::Writer
      end
    end

    describe RDF::RDFa::HTML do
      formats = [
        :html
      ].each do |arg|
        it "discovers with #{arg.inspect}" do
          RDF::Format.for(arg).should == RDF::RDFa::HTML
        end
      end

      it "should discover 'html'" do
        RDF::Format.for(:html).reader.should == RDF::RDFa::Reader
        RDF::Format.for(:html).writer.should == RDF::RDFa::Writer
      end
    end

    describe RDF::RDFa::Lite do
      formats = [
        :lite
      ].each do |arg|
        it "discovers with #{arg.inspect}" do
          RDF::Format.for(arg).should == RDF::RDFa::Lite
        end
      end

      it "should discover 'lite'" do
        RDF::Format.for(:lite).reader.should == RDF::RDFa::Reader
        RDF::Format.for(:lite).writer.should == RDF::RDFa::Writer
      end
    end

    describe RDF::RDFa::SVG do
      formats = [
        :svg,
        'etc/doap.svg',
        {:file_name      => 'etc/doap.svg'},
        {:file_extension => 'svg'},
        {:content_type   => 'image/svg+xml'},
      ].each do |arg|
        it "discovers with #{arg.inspect}" do
          RDF::Format.for(arg).should == RDF::RDFa::SVG
        end
      end

      it "should discover 'svg'" do
        RDF::Format.for(:svg).reader.should == RDF::RDFa::Reader
        RDF::Format.for(:svg).writer.should == RDF::RDFa::Writer
      end
    end
  end

  describe "#to_sym" do
    specify {@format_class.to_sym.should == :rdfa}
  end

  describe ".detect" do
    {
      :about    => '<div about="foo"></div>',
      :typeof   => '<div typeof="foo"></div>',
      :resource => '<div resource="foo"></div>',
      :vocab    => '<div vocab="foo"></div>',
      :prefix   => '<div prefix="foo"></div>',
      :property => '<div property="foo"></div>',
    }.each do |sym, str|
      it "detects #{sym}" do
        @format_class.detect(str).should be_true
      end
    end

    {
      :n3                   => "@prefix foo: <bar> .\nfoo:bar = {<a> <b> <c>} .",
      :nquads               => "<a> <b> <c> <d> . ",
      :rdfxml               => '<rdf:RDF about="foo"></rdf:RDF>',
      :jsonld               => '{"@context" => "foo"}',
      :ntriples             => "<a> <b> <c> .",
      :itemprop =>  '<div itemprop="bar"></div>',
      :itemtype =>  '<div itemtype="bar"></div>',
      :itemref =>   '<div itemref="bar"></div>',
      :itemscope => '<div itemscope=""></div>',
      :itemid =>    '<div itemid="bar"></div>',
      :multi_line           => '<a>\n  <b>\n  "literal"\n .',
      :turtle               => "@prefix foo: <bar> .\n foo:a foo:b <c> .",
      :STRING_LITERAL1      => %(<a> <b> 'literal' .),
      :STRING_LITERAL2      => %(<a> <b> "literal" .),
      :STRING_LITERAL_LONG1 => %(<a> <b> '''\nliteral\n''' .),
      :STRING_LITERAL_LONG2 => %(<a> <b> """\nliteral\n""" .),
    }.each do |sym, str|
      it "does not detect #{sym}" do
        @format_class.detect(str).should be_false
      end
    end
  end
end
