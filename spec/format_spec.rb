$:.unshift "."
require 'spec_helper'
require 'rdf/spec/format'

describe RDF::RDFa::Format do
  it_behaves_like 'an RDF::Format' do
    let(:format_class) {RDF::RDFa::Format}
  end

  describe ".for" do
    formats = [
      :rdfa, :lite, :html, :xhtml, :svg,
      'etc/doap.html',
      {file_name:      'etc/doap.html'},
      {file_extension: 'html'},
      {content_type:   'text/html'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        expect(RDF::Format.for(arg)).to eq RDF::RDFa::Format
      end
    end

    {
      rdfa:   '<div about="foo"></div>',
    }.each do |sym, str|
      it "detects #{sym}" do
        expect(RDF::RDFa::Format.for {str}).to eq RDF::RDFa::Format
      end
    end

    it "uses text/html as first content type" do
      expect(RDF::Format.for(:rdfa).content_type.first).to eq "text/html"
    end
  end

  describe "#to_sym" do
    specify {expect(RDF::RDFa::Format.to_sym).to eq :rdfa}
  end

  describe ".detect" do
    {
      about:    '<div about="foo"></div>',
      typeof:   '<div typeof="foo"></div>',
      resource: '<div resource="foo"></div>',
      vocab:    '<div vocab="foo"></div>',
      prefix:   '<div prefix="foo"></div>',
      property: '<div property="foo"></div>',
    }.each do |sym, str|
      it "detects #{sym}" do
        expect(RDF::RDFa::Format.detect(str)).to be_truthy
      end
    end

    {
      n3:                   "@prefix foo: <bar> .\nfoo:bar = {<a> <b> <c>} .",
      nquads:               "<a> <b> <c> <d> . ",
      rdfxml:               '<rdf:RDF about="foo"></rdf:RDF>',
      jsonld:               '{"@context" => "foo"}',
      ntriples:             "<a> <b> <c> .",
      itemprop:  '<div itemprop="bar"></div>',
      itemtype:  '<div itemtype="bar"></div>',
      itemref:   '<div itemref="bar"></div>',
      itemscope: '<div itemscope=""></div>',
      itemid:    '<div itemid="bar"></div>',
      multi_line:           '<a>\n  <b>\n  "literal"\n .',
      turtle:               "@prefix foo: <bar> .\n foo:a foo:b <c> .",
      STRING_LITERAL1:      %(<a> <b> 'literal' .),
      STRING_LITERAL2:      %(<a> <b> "literal" .),
      STRING_LITERAL_LONG1: %(<a> <b> '''\nliteral\n''' .),
      STRING_LITERAL_LONG2: %(<a> <b> """\nliteral\n""" .),
    }.each do |sym, str|
      it "does not detect #{sym}" do
        expect(RDF::RDFa::Format.detect(str)).to be_falsey
      end
    end
  end
end
