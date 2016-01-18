$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

describe "RDF::RDFa::Reader" do
  let(:logger) {RDF::Spec.logger}
  let!(:doap) {File.expand_path("../../etc/doap.html", __FILE__)}
  let!(:doap_nt) {File.expand_path("../../etc/doap.nt", __FILE__)}

  # @see lib/rdf/spec/reader.rb in rdf-spec
  it_behaves_like 'an RDF::Reader' do
    let(:reader_input) {File.read(doap)}
    let(:reader) {RDF::RDFa::Reader.new(reader_input)}
    let(:reader_count) {File.open(doap_nt).each_line.to_a.length}
    let(:reader_invalid_input) {""}
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
        expect(RDF::Reader.for(arg)).to eq RDF::RDFa::Reader
      end
    end
  end

  context :interface do
    subject {
      %(<?xml version="1.0" encoding="UTF-8"?>
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
      }

    it "yields reader" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::RDFa::Reader)
      RDF::RDFa::Reader.new(subject, base_uri: "http://example/") do |reader|
        inner.called(reader.class)
      end
    end

    it "returns reader" do
      expect(RDF::RDFa::Reader.new(subject, base_uri: "http://example/")).to be_a(RDF::RDFa::Reader)
    end

    it "yiels statements" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::Statement)
      RDF::RDFa::Reader.new(subject, base_uri: "http://example/").each_statement do |statement|
        inner.called(statement.class)
      end
    end

    it "yelds triples" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::URI, RDF::URI, RDF::Literal)
      RDF::RDFa::Reader.new(subject, base_uri: "http://example/").each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
    
    it "calls Proc with processor statements for :processor_callback" do
      lam = double("lambda")
      expect(lam).to receive(:call).at_least(1) {|s| expect(s).to be_statement}
      RDF::RDFa::Reader.new(subject, base_uri: "http://example/", processor_callback: lam).each_triple {}
    end
    
    context "rdfagraph option" do
      let(:source) do
        %(<!DOCTYPE html>
          <html>
            <span property="dc:title">Title</span>
            <span property="undefined:curie">Undefined Curie</span>
          </html>
        )
      end

      let(:output) do
        %(
          PREFIX dc: <http://purl.org/dc/terms/>
          ASK WHERE {
            ?s dc:title "Title" .
          }
        )
      end
      
      let(:processor) do
        %(
          PREFIX rdfa: <http://www.w3.org/ns/rdfa#>
          ASK WHERE {
            ?s a rdfa:Info .
          }
        )
      end

      it "generates output graph by default" do
        expect(parse(source)).to pass_query(output, logger: logger)
      end

      it "generates output graph with rdfagraph=output" do
        expect(parse(source, rdfagraph: :output)).to pass_query(output, logger: logger)
        expect(parse(source, rdfagraph: :output)).not_to pass_query(processor, logger: logger)
      end

      it "generates output graph with rdfagraph=[output]" do
        expect(parse(source, rdfagraph: [:output])).to pass_query(output, logger: logger)
      end

      it "generates output graph with rdfagraph=foo" do
        expect(parse(source, rdfagraph: :foo)).to pass_query(output, logger: logger)
      end

      it "generates processor graph with rdfagraph=processor" do
        expect(parse(source, rdfagraph: :processor)).to pass_query(processor, logger: logger)
        expect(parse(source, rdfagraph: :processor)).not_to pass_query(output, logger: logger)
      end

      it "generates both output and processor graphs with rdfagraph=[output,processor]" do
        expect(parse(source, rdfagraph: [:output, :processor])).to pass_query(output, logger: logger)
        expect(parse(source, rdfagraph: [:output, :processor])).to pass_query(processor, logger: logger)
      end

      it "generates both output and processor graphs with rdfagraph=output,processor" do
        expect(parse(source, rdfagraph: "output, processor")).to pass_query(output, logger: logger)
        expect(parse(source, rdfagraph: "output, processor")).to pass_query(processor, logger: logger)
      end
    end
  end

  begin
    require 'nokogiri'
  rescue LoadError
  end
  require 'rexml/document'

  %w(Nokogiri REXML).each do |impl|
    next unless Module.constants.map(&:to_s).include?(impl)
    context impl do
      before(:all) {@library = impl.downcase.to_s.to_sym}
      
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

          expect(parse(html)).to be_equivalent_graph(expected, logger: logger)
        end
      end

      context :features do
        describe "XML Literal", skip: "XMLLiteral matching becoming problematic" do
          it "rdf:XMLLiteral" do
            html = %(<?xml version="1.0" encoding="UTF-8"?>
              <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
              <html xmlns="http://www.w3.org/1999/xhtml">
                <head><base href=""/></head>
                <body>
                  <div about="http://example/">
                    <h2 property="dc:title" datatype="rdf:XMLLiteral">E = mc<sup>2</sup>: The Most Urgent Problem of Our Time</h2>
                </div>
                </body>
              </html>
              )
            expected = RDF::Graph.new << RDF::Turtle::Reader.new(%q(
              @base <http://example/> .
              @prefix dc: <http://purl.org/dc/terms/> .
              @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

              <> dc:title "E = mc<sup xmlns=\"http://www.w3.org/1999/xhtml\">2</sup>: The Most Urgent Problem of Our Time"^^rdf:XMLLiteral .
            ))

            expect(parse(html)).to be_equivalent_graph(expected, logger: logger)
          end
        end

        describe "HTML Literal" do
          it "rdf:HTML" do
            html = %(<!DOCTYPE html>
              <html>
                <head><base href=""/></head>
                <body>
                  <div about="http://example/">
                    <h2 property="dc:title" datatype="rdf:HTML">E = mc<sup>2</sup>: The Most Urgent Problem of Our Time</h2>
                </div>
                </body>
              </html>
              )
            expected = RDF::Graph.new << RDF::Turtle::Reader.new(%q(
              @base <http://example/> .
              @prefix dc: <http://purl.org/dc/terms/> .
              @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

              <> dc:title "E = mc<sup>2</sup>: The Most Urgent Problem of Our Time"^^rdf:HTML .
            ))

            expect(parse(html)).to be_equivalent_graph(expected, logger: logger)
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
            @base <http://example> .
            @prefix foaf: <http://xmlns.com/foaf/0.1/> .

             [ foaf:name "Manu Sporny";
               foaf:knows [ foaf:name "Ralph Swick"];
             ] .
          )

          expect(parse(html)).to be_equivalent_graph(expected, logger: logger)
        end

        describe "@about" do
          it "creates a statement with subject from @about" do
            html = %(
              <span about="foo" property="dc:title">Title</span>
            )
            expected = %q(
              @prefix dc: <http://purl.org/dc/terms/> .

              <foo> dc:title "Title" .
            )
            expect(parse(html)).to be_equivalent_graph(expected, logger: logger, format: :ttl)
          end
          
          it "creates a typed subject with @typeof" do
            html = %(
              <span about="foo" property="dc:title" typeof="rdfs:Resource">Title</span>
            )
            expected = %q(
              @prefix dc: <http://purl.org/dc/terms/> .
              @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

              <foo> a rdfs:Resource; dc:title "Title" .
            )
            expect(parse(html)).to be_equivalent_graph(expected, logger: logger, format: :ttl)
          end
        end

        describe "@resource" do
          it "creates a statement with object from @resource" do
            html = %(
              <div about="foo"><span resource="bar" rel="rdf:value"/></div>
            )
            expected = %q(
              @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
              <foo> rdf:value <bar> .
            )
            expect(parse(html)).to be_equivalent_graph(expected, logger: logger, format: :ttl)
          end

          it "creates a type on object with @typeof" do
            html = %(
              <div about="foo"><link resource="bar" rel="rdf:value" typeof="rdfs:Resource"/></div>
            )
            expected = %q(
              @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
              @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
              <foo> rdf:value <bar> .
              <bar> a rdfs:Resource .
            )
            expect(parse(html)).to be_equivalent_graph(expected, logger: logger, format: :ttl)
          end

          it "uses @resource as subject of child elements" do
            html = %(
              <div resource="foo"><span property="dc:title">Title</span></div>
            )
            expected = RDF::Graph.new << RDF::Statement.new(RDF::URI("foo"), RDF::Vocab::DC.title, "Title")
            expect(parse(html)).to be_equivalent_graph(expected, logger: logger, format: :ttl)
          end

          context :SafeCURIEorCURIEorIRI do
            {
              term: [
                %(<link about="" property="rdf:value" resource="describedby"/>),
                %q(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                  @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                  <> rdf:value <describedby> .
                )
              ],
              curie: [
                %(<link about="" property="rdf:value" resource="xhv:describedby"/>),
                %q(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                  @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                  <> rdf:value xhv:describedby .
                )
              ],
              save_curie: [
                %(<link about="" property="rdf:value" resource="[xhv:describedby]"/>),
                %q(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                  @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                  <> rdf:value xhv:describedby .
                )
              ],
            }.each do |test, (input, expected)|
              it "expands #{test}" do
                expect(parse(input)).to be_equivalent_graph(expected, logger: logger, format: :ttl)
              end
            end
          end
        end

        describe "@href" do
          it "creates a statement with object from @href" do
            html = %(
              <div about="foo"><a href="bar" rel="rdf:value"></a></div>
            )
            expected = RDF::Graph.new << RDF::Statement.new(RDF::URI("foo"), RDF.value, RDF::URI("bar"))
            expect(parse(html)).to be_equivalent_graph(expected, logger: logger, format: :ttl)
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
              expected = RDF::Graph.new << RDF::Statement.new(RDF::URI("bar"), RDF::Vocab::DC.title, "Title")
              expect(parse(subject, version: "rdfa1.0")).to be_equivalent_graph(expected, logger: logger, format: :ttl)
            end
          end
      
          context "RDFa 1.1" do
            it "creates a statement with object from @src" do
              expected = RDF::Graph.new <<
                RDF::Statement.new(RDF::URI("foo"), RDF.value, RDF::URI("bar")) <<
                RDF::Statement.new(RDF::URI("foo"), RDF::Vocab::DC.title, "Title")
              expect(parse(subject)).to be_equivalent_graph(expected, logger: logger, format: :ttl)
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
                  <div about="http://example/#me" typeof="foaf:Person">
                    <p property="foaf:name">John Doe</p>
                  </div>
                </body>
              </html>
              )
            expected = %(
              @prefix foaf: <http://xmlns.com/foaf/0.1/> .
              @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

              <http://example/#me> a foaf:Person;
                 foaf:name "John Doe" .
            )

            expect(parse(html)).to be_equivalent_graph(expected, logger: logger)
          end
          
          it "empty @typeof on root" do
            html = %(<html typeof=""><span property="dc:title">Title</span></html>)
            expected = RDF::Graph.new << RDF::Statement.new(RDF::URI(""), RDF::Vocab::DC.title, "Title")

            expect(parse(html)).to be_equivalent_graph(expected, logger: logger, format: :ttl)
          end
        end

        it "html>head>base" do
          html = %(<?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">
            <html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.1"
                xmlns:dc="http://purl.org/dc/elements/1.1/">
             <head>
                <base href="http://example/"></base>
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

            <http://example/faq> dc:title "Example FAQ" .
          )

          expect(parse(html)).to be_equivalent_graph(expected, logger: logger, format: :ttl)
        end

        describe "xml:base" do
          {
            xml: true,
            xhtml1: false,
            html4: false,
            html5: false,
            xhtml5: true,
            svg: true
          }.each do |hl, does|
            context "#{hl}" do
              it %(#{does ? "uses" : "does not use"} xml:base in root) do
                html = %(<div xml:base="http://example/">
                    <span property="rdf:value">Value</span>
                  </div>
                )
                expected_true = %(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

                  <http://example/> rdf:value "Value" .
                )
                expected_false = %(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

                  <http://example/doc_base> rdf:value "Value" .
                )
                expected = does ? expected_true : expected_false

                expect(parse(html, base_uri: "http://example/doc_base",
                  version: :"rdfa1.1",
                  host_language: hl
                )).to be_equivalent_graph(expected, logger: logger, format: :ttl)
              end
              
              it %(#{does ? "uses" : "does not use"} xml:base in non-root) do
                html = %(<div xml:base="http://example/">
                    <a xml:base="http://example/" property="rdf:value" href="">Value</a>
                  </div>
                )
                expected_true = %(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

                  <http://example/> rdf:value <http://example/> .
                )
                expected_false = %(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

                  <http://example/doc_base> rdf:value <http://example/doc_base> .
                )
                expected = does ? expected_true : expected_false

                expect(parse(html, base_uri: "http://example/doc_base",
                  version: :"rdfa1.1",
                  host_language: hl
                )).to be_equivalent_graph(expected, logger: logger, format: :ttl)
              end
            end
          end
        end

        describe "empty CURIE" do
          {
            "ignores about with typeof" => [
              %(<div about="[]" typeof="foaf:Person" property="foaf:name">Alex Milowski</div>),
              %(
                @prefix foaf: <http://xmlns.com/foaf/0.1/> .
                <> foaf:name "Alex Milowski" .
                [ a foaf:Person ] .
              )
            ],
            "ignores about with chaining" => [
              %(
                <div about="[]" typeof="foaf:Person">
                  <span property="foaf:name">Alex Milowski</span>
                </div>
              ),
              %(
                @prefix foaf: <http://xmlns.com/foaf/0.1/> .
                [a foaf:Person; foaf:name "Alex Milowski"] .
              )
            ],
            "ignores resource with href (rel)" => [
              %(<a href="license.xhtml" rel="license" resource="[]">The Foo Document</a>),
              %(
                @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                <> xhv:license <license.xhtml> .
              )
            ],
            "ignores resource with href (property)" => [
              %(<a href="license.xhtml" property="license" resource="[]">The Foo Document</a>),
              %(
                @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                <> xhv:license <license.xhtml> .
              )
            ],
          }.each do |name, (html,expected)|
            it name do
              expect(parse("<html>#{html}</html>", version: :"rdfa1.1")).to be_equivalent_graph(expected, logger: logger, format: :ttl)
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
                  @expected = RDF::Graph.new << RDF::Statement.new(RDF::URI(""), RDF.value, RDF::Literal.new(value, datatype: dt_uri))
                end

                context "with #{value}" do
                  it "creates triple with invalid literal" do
                    expect(parse(@rdfa, validate: false)).to be_equivalent_graph(@expected, logger: logger)
                  end
            
                  it "does not create triple when validating" do
                    expect {parse(@rdfa, validate: true)}.to raise_error(RDF::ReaderError)
                  end
                end
              end
            end
          end
        end

        context "CURIEs" do
          it "accepts a CURIE with a local part having a ':'" do
            html = %(
              <html prefix="foo: http://example/">
                <div property="foo:due:to:facebook:interpretation:of:CURIE">Value</div>
              </html>
            )
            expected = RDF::Graph.new << RDF::Statement.new(
              RDF::URI(""),
              RDF::URI("http://example/due:to:facebook:interpretation:of:CURIE"),
              "Value"
            )
            expect(parse(html)).to be_equivalent_graph(expected, logger: logger)
          end
        end

        context "@vocab" do
          subject {%q(
            <html>
              <head>
                <base href="http://example/"/>
              </head>
              <body>
                <div about ="#me" vocab="http://xmlns.com/foaf/0.1/" typeof="Person" >
                  <p property="name">Gregg Kellogg</p>
                </div>
              </body>
            </html>
          )}
      
          it "uses vocabulary when creating property IRI" do
            query = %q(
              PREFIX foaf: <http://xmlns.com/foaf/0.1/>
              ASK WHERE { <http://example/#me> a foaf:Person }
            )
            expect(parse(subject)).to pass_query(query, logger: logger)
          end

          it "uses vocabulary when creating type IRI" do
            query = %q(
              PREFIX foaf: <http://xmlns.com/foaf/0.1/>
              ASK WHERE { <http://example/#me> foaf:name "Gregg Kellogg" }
            )
            expect(parse(subject)).to pass_query(query, logger: logger)
          end

          it "adds rdfa:hasProperty triple" do
            query = %q(
              PREFIX foaf: <http://xmlns.com/foaf/0.1/>
              PREFIX rdfa: <http://www.w3.org/ns/rdfa#>
              ASK WHERE { <http://example/> rdfa:usesVocabulary foaf: }
            )
            expect(parse(subject)).to pass_query(query, logger: logger)
          end
          
          context "with terms" do
            [
              %q(term),
              %q(A/B),
              %q(a09b),
              %q(a_b),
              %q(a.b),
              #%q(\u002e_escaped_unicode),
            ].each do |term|
              it "accepts #{term.inspect}" do
                input = %(
                  <span vocab="http://example/" property="#{term}">Foo</span>
                )
                query = %(
                  ASK WHERE { <http://example/> <http://example/#{term}> "Foo" }
                )
                expect(parse(input, validate: false, base_uri: "http://example/")).to pass_query(query, logger: logger)
              end
            end

            [
              %q(prefix:suffix),
              #%q(a b),
              %q(/path),
              %q(1leading_numeric),
              %q(\u0301foo),
            ].each do |term|
              it "rejects #{term.inspect}" do
                input = %(
                  <span vocab="http://example/" property="#{term}">Foo</span>
                )
                query = %(
                  ASK WHERE { <http://example/> <http://example/#{term}> "Foo" }
                )
                expect(parse(input, base_uri: "http://example/")).to_not pass_query(query, logger: logger)
              end
            end
          end
        end

        context "@inlist" do
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
            
                <http://example/> rdf:value () .
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
            
                <http://example/> rdf:value ("Foo") .
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
            
                <http://example/> rdf:value (<http://example/foo>) .
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
            
                <http://example/> rdf:value ("Foo" <http://example/foo>) .
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
            
                <http://example/> rdf:value ("Foo" "Bar") .
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
            
                <http://example/> rdf:value ("Foo" "Bar"), "Baz" .
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
            
                <http://example/> rdf:value (<http://example/foo> <http://example/bar>) .
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
            
                <http://example/foo> rdf:value ("Foo"), ("Bar") .
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
            
                <http://example/> rdf:value ("Foo"); rdf:inlist <http://example/res> .
                <http://example/res> rdf:value ("Bar") .
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
            
                <http://example/> rdf:value ("Foo"); rdf:inlist <http://example/res> .
                <http://example/res> rdf:value ("Bar") .
              )
            ],
          }.each do |test, (input, expected)|
            it test do
              expect(parse(input, base_uri: "http://example/")).to be_equivalent_graph(expected, logger: logger, format: :ttl)
            end
          end
        end

        context "@property" do
          {
            "with text content" => [
              %q(
                <div about="">
                  <p property="rdf:value">Foo</p>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "Foo" .
              )
            ],
            "with @lang" => [
              %q(
                <div about="">
                  <p property="rdf:value" lang="en">Foo</p>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "Foo"@en .
              )
            ],
            "with @xml:lang" => [
              %q(
                <div about="">
                  <p property="rdf:value" xml:lang="en">Foo</p>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "Foo"@en .
              )
            ],
            "with @content" => [
              %q(
                <div about="">
                  <title property="rdf:value" content="Foo">Bar</title>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "Foo" .
              )
            ],
            "with @href" => [
              %q(
                <div about="">
                  <a property="rdf:value" href="#foo">Bar</a>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value <http://example/#foo> .
              )
            ],
            "with @src" => [
              %q(
                <div about="">
                  <img property="rdf:value" src="#foo"/>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value <http://example/#foo> .
              )
            ],
            "with <time>=xsd:time" => [
              %q(
                <div about="">
                  <time property="rdf:value">00:00:00Z</time>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "00:00:00Z"^^<http://www.w3.org/2001/XMLSchema#time> .
              )
            ],
            "with @datetime=xsd:date" => [
              %q(
                <div about="">
                  <time property="rdf:value" datetime="2011-06-28Z">28 June 2011</time>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "2011-06-28Z"^^<http://www.w3.org/2001/XMLSchema#date> .
              )
            ],
            "with @datetime=xsd:time" => [
              %q(
                <div about="">
                  <time property="rdf:value" datetime="00:00:00Z">midnight</time>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "00:00:00Z"^^<http://www.w3.org/2001/XMLSchema#time> .
              )
            ],
            "with @datetime=xsd:dateTime" => [
              %q(
                <div about="">
                  <time property="rdf:value" datetime="2011-06-28T00:00:00Z">28 June 2011 at midnight</time>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "2011-06-28T00:00:00Z"^^<http://www.w3.org/2001/XMLSchema#dateTime> .
              )
            ],
            "with @datetime=xsd:dateTime with TZ offset" => [
              %q(
                <div about="">
                  <time property="rdf:value" datetime="2011-06-28T00:00:00-08:00">28 June 2011 at midnight in San Francisco</time>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "2011-06-28T00:00:00-08:00"^^<http://www.w3.org/2001/XMLSchema#dateTime> .
              )
            ],
            "with @datetime=xsd:dateTime with @datatype" => [
              %q(
                <div about="">
                  <time property="rdf:value" datetime="2012-03-18T00:00:00Z" datatype="xsd:string"> March 2012 at midnight in San Francisco</time>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
          
                <http://example/> rdf:value "2012-03-18T00:00:00Z"^^xsd:string .
              )
            ],
            "with @datetime=xsd:gYear" => [
              %q(
                <div about="">
                  <time property="rdf:value" datetime="2011">2011</time>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "2011"^^<http://www.w3.org/2001/XMLSchema#gYear> .
              )
            ],
            "with @datetime=xsd:gYearMonth" => [
              %q(
                <div about="">
                  <time property="rdf:value" datetime="2011-06">2011</time>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "2011-06"^^<http://www.w3.org/2001/XMLSchema#gYearMonth> .
              )
            ],
            "with @datetime=xsd:duration" => [
              %q(
                <div about="">
                  <time property="rdf:value" datetime="P2011Y06M28DT00H00M00S">2011 years 6 months 28 days</time>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "P2011Y06M28DT00H00M00S"^^<http://www.w3.org/2001/XMLSchema#duration> .
              )
            ],
            "with @datetime=plain" => [
              %q(
                <div about="">
                  <time property="rdf:value" datetime="foo">Foo</time>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "foo" .
              )
            ],
            "with @datetime=plain with @lang" => [
              %q(
                <div about="">
                  <time property="rdf:value" lang="en" datetime="D-Day">Foo</time>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value "D-Day"@en .
              )
            ],
            "with @datetime and @content" => [
              %q(
                <div about="">
                  <time property="rdf:value" datetime="2012-03-18" content="this">18 March 2012</time>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
          
                <http://example/> rdf:value "this" .
              )
            ],
            "with @resource" => [
              %q(
                <div about="">
                  <p property="rdf:value" resource="#foo">Bar</p>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value <http://example/#foo> .
              )
            ],
            "with @typeof" => [
              %q(
                <div about="">
                  <div property="rdf:value" typeof="">Bar</div>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value [] .
              )
            ],
            "with @about" => [
              %q(
                <div about="">
                  <div property="rdf:value" about="#foo"> <p property="rdf:value">Bar</p> </div>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/#foo> rdf:value " Bar ", "Bar" .
              )
            ],
            "@href and @property no-chaining" => [
              %q(
                <div about="">
                  <a property="rdf:value" href="#foo">
                    <span property="rdf:value">Bar</span>
                  </a>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
                <http://example/> rdf:value <http://example/#foo>, "Bar" .
              )
            ],
            "@href, @typeof and @property chaining" => [
              %q(
                <div typeof="foaf:Person" about="http://greggkellogg.net/foaf#me">
                  <p property="foaf:name">Gregg Kellogg</p>
                  <p property="foaf:knows" typeof="foaf:Person" href="http://manu.sporny.org/#this">
                    <span property="foaf:name">Manu Sporny</span>
                  </p>
                </div>
              ),
              %q(
                @prefix foaf: <http://xmlns.com/foaf/0.1/> .
                <http://greggkellogg.net/foaf#me> a foaf:Person;
                  foaf:name "Gregg Kellogg";
                  foaf:knows <http://manu.sporny.org/#this> .
                <http://manu.sporny.org/#this> a foaf:Person;
                  foaf:name "Manu Sporny" .
              )
            ],
            "@property with @href in a list" => [
              %q(
                <div about="http://example">
                  <a inlist="" property="rdf:value" href="http://example#foo"></a>
                  <a inlist="" property="rdf:value" href="http://example#bar"></a>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                <http://example> rdf:value ( <http://example#foo> <http://example#bar> ).
              )
            ],
            "@property and @rel with @href in a list" => [
              %q(
                <div about="http://example">
                  <a inlist="" property="rdf:value" href="http://example#foo"></a>
                  <a inlist="" rel="rdf:value" href="http://example#bar"></a>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                <http://example> rdf:value ( <http://example#foo> <http://example#bar> ).
              )
            ],
            #"@property and @typeof and incomplete triples" => [
            #  %q(
            #    <div about="http://greggkellogg.net/foaf#me" rel="foaf:knows">
            #      <span property="foaf:name" typeof="foaf:Person">Ivan Herman</span>
            #    </div>
            #  ),
            #  %q(
            #    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
            #    <http://greggkellogg.net/foaf#me> foaf:knows [
            #      foaf:name "Ivan Herman"
            #    ].
            #    [ a foaf:Person ] .
            #  )
            #],
            #"@property, @href and @typeof and incomplete triples" => [
            #  %q(
            #    <div about="http://greggkellogg.net/foaf#me" rel="foaf:knows">
            #      <a href="http://www.ivan-herman.net/foaf#me" property="foaf:name" typeof="foaf:Person">Ivan Herman</a>
            #    </div>
            #  ),
            #  %q(
            #    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
            #    <http://greggkellogg.net/foaf#me> foaf:knows [ foaf:name "Ivan Herman"] .
            #    <http://www.ivan-herman.net/foaf#me> a foaf:Person .
            #  )
            #],
            "@property, @href and @datatype" => [
              %q(
                <a href="http://example/" property="rdf:value" datatype="">value</a>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                <http://example/> rdf:value "value" .
              )
            ],
            "@property, @datatype and @language" => [
              %q(
                <div about="http://example/">
                  <span property="rdf:value" lang="en" datatype="xsd:date">value</span>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
                <http://example/> rdf:value "value"^^xsd:date .
              )
            ],
            "@property, @content, @datatype and @language" => [
              %q(
                <div about="http://example/">
                  <span property="rdf:value" lang="en" datatype="xsd:date" content="value">not this</span>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
                <http://example/> rdf:value "value"^^xsd:date .
              )
            ],
            "@property, and @value as integer" => [
              %q(
                <div about="http://example/">
                  <data property="rdf:value" value="1"/>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
                <http://example/> rdf:value 1 .
              )
            ],
            "@property, and @value as decimal" => [
              %q(
                <div about="http://example/">
                  <data property="rdf:value" value="1.1"/>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
                <http://example/> rdf:value 1.1 .
              )
            ],
            "@property, and @value as double" => [
              %q(
                <div about="http://example/">
                  <data property="rdf:value" value="1.1e1"/>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
                <http://example/> rdf:value 1.1e1 .
              )
            ],
            "@property, and @value as integer with datatype" => [
              %q(
                <div about="http://example/">
                  <data property="rdf:value" value="1" datatype="xsd:float"/>
                </div>
              ),
              %q(
                @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
                <http://example/> rdf:value "1"^^xsd:float .
              )
            ],
          }.each do |test, (input, expected)|
            it test do
              expect(parse(input, base_uri: "http://example/")).to be_equivalent_graph(expected, logger: logger, format: :ttl)
            end
          end
        end

        context "with @rel/@rev" do
          {
            "with CURIE" => [
              %q(<a about="" property="rdf:value" rel="xhv:license" href="http://example/">Foo</a>),
              %q(<> rdf:value "Foo"; xhv:license <http://example/> .),
              %q(<> rdf:value "Foo"; xhv:license <http://example/> .)
            ],
            "with Term" => [
              %q(<a about="" property="rdf:value" rel="license" href="http://example/">Foo</a>),
              %q(<> rdf:value "Foo"; xhv:license <http://example/> .),
              %q(<> rdf:value <http://example/> .)
            ],
            "with Term and CURIE" => [
              %q(<a about="" property="rdf:value" rel="license cc:license" href="http://example/">Foo</a>),
              %q(<> rdf:value "Foo"; cc:license <http://example/>; xhv:license <http://example/> .),
              %q(<> rdf:value "Foo"; cc:license <http://example/> .),
            ],
          }.each do |test, (input, expected1, expected5)|
            context test do
              it "xhtml1" do
                expected1 = %(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                  @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                  @prefix cc: <http://creativecommons.org/ns#> .
                ) + expected1
                expect(parse(input, host_language: :xhtml1)).to be_equivalent_graph(expected1, logger: logger, format: :ttl)
              end
            
              it "xhtml5" do
                expected5 = %(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                  @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                  @prefix cc: <http://creativecommons.org/ns#> .
                ) + expected5
                expect(parse(input, host_language: :xhtml5)).to be_equivalent_graph(expected5, logger: logger, format: :ttl)
              end
            end
          end
        end
        
        context "@role" do
          {
            "with @id" => [
              %(
                <div id="heading1" role="heading">
                  <p>Some contents that are a header</p>
                </div>
              ),
              %(
                @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                <#heading1> xhv:role xhv:heading.
              )
            ],
            "no @id" => [
              %(
                <div role="heading">
                  <p>Some contents that are a header</p>
                </div>
              ),
              %(
                @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                [xhv:role xhv:heading].
              )
            ],
            "@id and IRI object" => [
              %(
                <div id="therole" role="http://example/roles/somerole">
                  <p>Some contents that are a header</p>
                </div>
              ),
              %(
                @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                <#therole> xhv:role <http://example/roles/somerole>.
              )
            ],
            "@id and CURIE object" => [
              %(
                <div prefix="ex: http://example/roles/"
                     id="therole"
                     role="ex:somerole">
                  <p>Some contents that are a header</p>
                </div>
              ),
              %(
                @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                <#therole> xhv:role <http://example/roles/somerole>.
              )
            ],
            "multiple values" => [
              %(
                <div prefix="ex: http://example/roles/"
                     id="therole"
                     role="ex:somerole someOtherRole http://example/alternate/role noprefix:final">
                  <p>Some contents that are a header</p>
                </div>
              ),
              %(
                @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                <#therole> xhv:role <http://example/roles/somerole>,
                  xhv:someOtherRole,
                  <http://example/alternate/role>,
                  <noprefix:final>.
              )
            ],
          }.each do |title, (input, expected)|
            it title do
              expect(parse(input)).to be_equivalent_graph(expected, logger: logger, format: :ttl)
            end
          end
        end
      end

      context "problematic examples" do
        {
          "Jen's Ice Cream example" => [
            %q(<root><div vocab="#" typeof="">
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
            </div></root>),
            %q(
            <> <http://www.w3.org/ns/rdfa#usesVocabulary> <#>, <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            _:a <#flavor> ("Lemon sorbet" "Apricot sorbet") .
            )
          ],
          "schema.org Event with @property" => [
            %q(
              <div>
                <div vocab="http://schema.org/" typeof="Event">
                  <a property="url" href="nba-miami-philidelphia-game3.html">
                    <span property="description">
                      NBA Eastern Conference First Round Playoff Tickets:
                      Miami Heat at Philadelphia 76ers - Game 3 (Home Game 1)
                    </span>
                  </a>
                </div>
              </div>
            ),
            %q(
              @prefix schema: <http://schema.org/> .
              <> <http://www.w3.org/ns/rdfa#usesVocabulary> <http://schema.org/> .
              [ a schema:Event;
                schema:url <nba-miami-philidelphia-game3.html>;
                schema:description """
                      NBA Eastern Conference First Round Playoff Tickets:
                      Miami Heat at Philadelphia 76ers - Game 3 (Home Game 1)
                    """ ] .
            )
          ],
          "schema.org Event with @property and @typeof chain" => [
            %q(
              <div>
                <div vocab="http://schema.org/" typeof="Event">
                  <div property="offers" typeof="AggregateOffer">
                    Priced from: <span property="lowPrice">$35</span>
                    <span property="offerCount">1,938</span> tickets left
                  </div>
                </div>
              </div>
            ),
            %q(
              @prefix schema: <http://schema.org/> .
              <> <http://www.w3.org/ns/rdfa#usesVocabulary> <http://schema.org/> .
              [ a schema:Event;
                schema:offers [
                  a schema:AggregateOffer;
                  schema:lowPrice "$35";
                  schema:offerCount "1,938"
                ]
              ] .
            )
          ],
          "drupal confused @property with hanging @rel" => [
            %q(
              <li rel="dc:subject">
                  <a property="rdfs:label skos:prefLabel"
                     typeof="skos:Concept"
                     href="/plain/?q=taxonomy/term/1"
                  >xy</a>
              </li>
            ),
            %q(
              @prefix dc: <http://purl.org/dc/terms/> .
              @prefix skos: <http://www.w3.org/2004/02/skos/core#> .
              @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
              <> dc:subject [ rdfs:label </plain/?q=taxonomy/term/1>;
                         skos:prefLabel </plain/?q=taxonomy/term/1> ] .

              </plain/?q=taxonomy/term/1> a skos:Concept .
            )
          ],
          "bbc programs @rel=role with rfds:label" => [
            %q(
              <dt rel="po:role" class="role" prefix="po: http://example/">
                <span typeof="po:Role" property="rdfs:label">Director</span>
              </dt>
            ),
            %q(
              @prefix po: <http://example/> .
              @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

              <> po:role [ rdfs:label [ a po:Role ] ] .
            )
          ],
        }.each do |title, (html, ttl)|
          it "parses #{title}" do
            g_ttl = RDF::Graph.new << RDF::Turtle::Reader.new(ttl)
            expect(parse(html, validate: false)).to be_equivalent_graph(g_ttl, logger: logger, format: :ttl)
          end
        end
      end

      context "SVG metadata" do
        it "extracts RDF/XML from <metadata> element" do
          svg = %(<?xml version="1.0" encoding="UTF-8"?>
            <svg width="12cm" height="4cm" viewBox="0 0 1200 400"
            xmlns:dc="http://purl.org/dc/terms/"
            xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
            xml:base="http://example.net/"
            xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny">
              <desc property="dc:description">A yellow rectangle with sharp corners.</desc>
              <metadata>
                <rdf:RDF>
                  <rdf:Description rdf:about="">
                    <dc:title>Test 0304</dc:title>
                  </rdf:Description>
                </rdf:RDF>
              </metadata>
              <!-- Show outline of canvas using 'rect' element -->
              <rect x="1" y="1" width="1198" height="398"
                    fill="none" stroke="blue" stroke-width="2"/>
              <rect x="400" y="100" width="400" height="200"
                    fill="yellow" stroke="navy" stroke-width="10"  />
            </svg>
          )
          query = %(
            ASK WHERE {
            	<http://example.net/> <http://purl.org/dc/terms/title> "Test 0304" .
            	<http://example.net/> <http://purl.org/dc/terms/description> "A yellow rectangle with sharp corners." .
            }
          )
          expect(parse(svg)).to pass_query(query, logger: logger)
        end
      end
      
      context "script" do
        {
          "text/turtle" => [
            %q(
              <script type="text/turtle"><![CDATA[
              @prefix dc: <http://purl.org/dc/terms/> .
              @prefix frbr: <http://purl.org/vocab/frbr/core#> .

              <http://books.example.com/works/45U8QJGZSQKDH8N> a frbr:Work ;
                   dc:creator "Wil Wheaton"@en ;
                   dc:title "Just a Geek"@en ;
                   frbr:realization <http://books.example.com/products/9780596007683.BOOK>,
                       <http://books.example.com/products/9780596802189.EBOOK> .

              <http://books.example.com/products/9780596007683.BOOK> a frbr:Expression ;
                   dc:type <http://books.example.com/product-types/BOOK> .

              <http://books.example.com/products/9780596802189.EBOOK> a frbr:Expression ;
                   dc:type <http://books.example.com/product-types/EBOOK> .
              ]]></script>
            ),
            %q(
              @prefix dc: <http://purl.org/dc/terms/> .
              @prefix frbr: <http://purl.org/vocab/frbr/core#> .

              <http://books.example.com/works/45U8QJGZSQKDH8N> a frbr:Work ;
                   dc:creator "Wil Wheaton"@en ;
                   dc:title "Just a Geek"@en ;
                   frbr:realization <http://books.example.com/products/9780596007683.BOOK>,
                       <http://books.example.com/products/9780596802189.EBOOK> .

              <http://books.example.com/products/9780596007683.BOOK> a frbr:Expression ;
                   dc:type <http://books.example.com/product-types/BOOK> .

              <http://books.example.com/products/9780596802189.EBOOK> a frbr:Expression ;
                   dc:type <http://books.example.com/product-types/EBOOK> .
            )
          ],
          "application/n-triples" => [
            %q(
              <script type="application/n-triples"><![CDATA[
              <http://one.example/subject1> <http://one.example/predicate1> <http://one.example/object1> .
              _:subject1 <http://an.example/predicate1> "object1" .
              _:subject2 <http://an.example/predicate2> "object2" .
              ]]></script>
            ),
            %q(
              <http://one.example/subject1> <http://one.example/predicate1> <http://one.example/object1> . # comments here
              # or on a line by themselves
              _:subject1 <http://an.example/predicate1> "object1" .
              _:subject2 <http://an.example/predicate2> "object2" .
            )
          ],
          "text/turtle with @id" => [
            %q(
              <script type="text/turtle" id="graph1"><![CDATA[
                 @prefix foo:  <http://example/xyz#> .
                 @prefix gr:   <http://purl.org/goodrelations/v1#> .
                 @prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .
                 @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

                 foo:myCompany
                   a gr:BusinessEntity ;
                   rdfs:seeAlso <http://example/xyz> ;
                   gr:hasLegalName "Hepp Industries Ltd."^^xsd:string .
              ]]></script>
            ),
            %q(
              @prefix foo:  <http://example/xyz#> .
              @prefix gr:   <http://purl.org/goodrelations/v1#> .
              @prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .
              @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

              foo:myCompany
                a gr:BusinessEntity ;
                rdfs:seeAlso <http://example/xyz> ;
                gr:hasLegalName "Hepp Industries Ltd."^^xsd:string .
            )
          ],
          "text/turtle with relatie IRIs" => [
            %q(
              <script type="text/turtle" id="graph1"><![CDATA[
                 @prefix gr:   <http://purl.org/goodrelations/v1#> .
                 @prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .
                 @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

                 <myCompany>
                   a gr:BusinessEntity ;
                   rdfs:seeAlso <xyz> ;
                   gr:hasLegalName "Hepp Industries Ltd."^^xsd:string .
              ]]></script>
            ),
            %q(
              @prefix gr:   <http://purl.org/goodrelations/v1#> .
              @prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .
              @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

              <http://example/myCompany>
                a gr:BusinessEntity ;
                rdfs:seeAlso <http://example/xyz> ;
                gr:hasLegalName "Hepp Industries Ltd."^^xsd:string .
            )
          ],
          "application/ld+json" => [
            %q(
              <script type="application/ld+json"><![CDATA[
                {
                  "@context": {
                    "foo": "http://example/xyz#",
                    "gr": "http://purl.org/goodrelations/v1#",
                    "xsd": "http://www.w3.org/2001/XMLSchema#",
                    "rdfs": "http://www.w3.org/2000/01/rdf-schema#"
                  },
                  "@id": "foo:myCompany",
                  "@type": "gr:BusinessEntity",
                  "rdfs:seeAlso": {"@id": "http://example/xyz"},
                  "gr:hasLegalName": "Hepp Industries Ltd."
                }
              ]]></script>
            ),
            %q(
              @prefix foo:  <http://example/xyz#> .
              @prefix gr:   <http://purl.org/goodrelations/v1#> .
              @prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .
              @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

              foo:myCompany
                a gr:BusinessEntity ;
                rdfs:seeAlso <http://example/xyz> ;
                gr:hasLegalName "Hepp Industries Ltd."^^xsd:string .
            )
          ],
          "application/ld+json with junk" => [
            %q(
              <script type="application/ld+json"><![CDATA[
                // This is a comment
                {
                  "@context": {
                    "foo": "http://example/xyz#",
                    "gr": "http://purl.org/goodrelations/v1#",
                    "xsd": "http://www.w3.org/2001/XMLSchema#",
                    "rdfs": "http://www.w3.org/2000/01/rdf-schema#"
                  },
                  "@id": "foo:myCompany",
                  "@type": "gr:BusinessEntity",
                  "rdfs:seeAlso": {"@id": "http://example/xyz"},
                  "gr:hasLegalName": "Hepp Industries Ltd."
                }
              ]]></script>
            ),
            %q(
              @prefix foo:  <http://example/xyz#> .
              @prefix gr:   <http://purl.org/goodrelations/v1#> .
              @prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .
              @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

              foo:myCompany
                a gr:BusinessEntity ;
                rdfs:seeAlso <http://example/xyz> ;
                gr:hasLegalName "Hepp Industries Ltd."^^xsd:string .
            )
          ]
        }.each do |title, (input,result)|
          it title do
            expect(parse(input, base_uri: "http://example/")).to be_equivalent_graph(result, logger: logger)
          end
        end
      end

      it "extracts microdata", skip: ("Not for REXML" if impl == 'REXML') do
        html = %(
          <html>
            <head>
              <title>Test 001</title>
            </head>
            <body>
              <p itemscope='true' itemtype="http://schema.org/Person">
                This test created by
                <span itemprop="name">Gregg Kellogg</span>.
              </p>
            </body>
          </html>
        )
        ttl = %(
          @prefix schema: <http://schema.org/> .

          [ a schema:Person; schema:name "Gregg Kellogg"] .
        )
        expect(parse(html)).to be_equivalent_graph(ttl, logger: logger)
      end

      context :rdfagraph do
        it "generates rdfa:Error on malformed content" do
          html = %(<!DOCTYPE html>
            <div Invalid markup
          )
          query = %(
            PREFIX dc: <http://purl.org/dc/terms/>
            PREFIX rdfa: <http://www.w3.org/ns/rdfa#>
            PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
            ASK WHERE {
              ?s a rdfa:Error;
                 dc:date ?date;
                 dc:description ?description .
              FILTER (datatype(?date) = xsd:date)
            }
          )
          expect(parse(html, rdfagraph: :processor)).to pass_query(query, logger: logger)
        end
        
        it "generates rdfa:UnresolvedCURIE on missing CURIE definition" do
          html = %(<!DOCTYPE html>
            <div property="rdf:value" resource="[undefined:curie]">Undefined Curie</div>
          )
          query = %(
            PREFIX dc: <http://purl.org/dc/terms/>
            PREFIX rdfa: <http://www.w3.org/ns/rdfa#>
            PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
            ASK WHERE {
              ?s a rdfa:UnresolvedCURIE;
                 dc:date ?date;
                 dc:description ?description .
              FILTER (datatype(?date) = xsd:date)
            }
          )
          expect(parse(html, rdfagraph: :processor)).to pass_query(query, logger: logger)
        end
        
        %w(
          \x01foo
          foo\x01
          $foo
        ).each do |prefix|
          it "generates rdfa:UnresolvedCURIE on malformed CURIE prefix #{prefix.inspect}" do
            html = %(<!DOCTYPE html>
              <div prefix="#{prefix}: http://example/"
                   property="rdf:value"
                   resource="[#{prefix}:malformed]">
                Malformed Prefix
              </div>
            )
            query = %(
              PREFIX dc: <http://purl.org/dc/terms/>
              PREFIX rdfa: <http://www.w3.org/ns/rdfa#>
              PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
              ASK WHERE {
                ?s a rdfa:UnresolvedCURIE;
                   dc:date ?date;
                   dc:description ?description .
                FILTER (datatype(?date) = xsd:date)
              }
            )
            expect(parse(html, rdfagraph: :processor)).to pass_query(query, logger: logger)
          end
        end
        
        it "generates rdfa:UnresolvedTerm on missing Term definition" do
          html = %(<!DOCTYPE html>
            <div property="undefined_term">Undefined Term</div>
          )
          query = %(
            PREFIX dc: <http://purl.org/dc/terms/>
            PREFIX rdfa: <http://www.w3.org/ns/rdfa#>
            PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
            ASK WHERE {
              ?s a rdfa:UnresolvedTerm;
                 dc:date ?date;
                 dc:description ?description .
              FILTER (datatype(?date) = xsd:date)
            }
          )
          expect(parse(html, rdfagraph: :processor)).to pass_query(query, logger: logger)
        end
      end

      context :validation do
        it "needs some examples", pending: true
      end
    end
  end

  describe "Base IRI resolution" do
    # From https://gist.github.com/RubenVerborgh/39f0e8d63e33e435371a
    let(:html) {%q{<html><body>
      <div xml:base="http://a/bb/ccc/d;p?q">
        <!-- RFC3986 normal examples -->
        <link about="urn:ex:s001" property="urn:ex:p" href="g:h"/>
        <link about="urn:ex:s002" property="urn:ex:p" href="g"/>
        <link about="urn:ex:s003" property="urn:ex:p" href="./g"/>
        <link about="urn:ex:s004" property="urn:ex:p" href="g/"/>
        <link about="urn:ex:s005" property="urn:ex:p" href="/g"/>
        <link about="urn:ex:s006" property="urn:ex:p" href="//g"/>
        <link about="urn:ex:s007" property="urn:ex:p" href="?y"/>
        <link about="urn:ex:s008" property="urn:ex:p" href="g?y"/>
        <link about="urn:ex:s009" property="urn:ex:p" href="#s"/>
        <link about="urn:ex:s010" property="urn:ex:p" href="g#s"/>
        <link about="urn:ex:s011" property="urn:ex:p" href="g?y#s"/>
        <link about="urn:ex:s012" property="urn:ex:p" href=";x"/>
        <link about="urn:ex:s013" property="urn:ex:p" href="g;x"/>
        <link about="urn:ex:s014" property="urn:ex:p" href="g;x?y#s"/>
        <link about="urn:ex:s015" property="urn:ex:p" href=""/>
        <link about="urn:ex:s016" property="urn:ex:p" href="."/>
        <link about="urn:ex:s017" property="urn:ex:p" href="./"/>
        <link about="urn:ex:s018" property="urn:ex:p" href=".."/>
        <link about="urn:ex:s019" property="urn:ex:p" href="../"/>
        <link about="urn:ex:s020" property="urn:ex:p" href="../g"/>
        <link about="urn:ex:s021" property="urn:ex:p" href="../.."/>
        <link about="urn:ex:s022" property="urn:ex:p" href="../../"/>
        <link about="urn:ex:s023" property="urn:ex:p" href="../../g"/>
      </div>

      <div xml:base="http://a/bb/ccc/d;p?q">
        <!-- RFC3986 abnormal examples -->
        <link about="urn:ex:s024" property="urn:ex:p" href="../../../g"/>
        <link about="urn:ex:s025" property="urn:ex:p" href="../../../../g"/>
        <link about="urn:ex:s026" property="urn:ex:p" href="/./g"/>
        <link about="urn:ex:s027" property="urn:ex:p" href="/../g"/>
        <link about="urn:ex:s028" property="urn:ex:p" href="g."/>
        <link about="urn:ex:s029" property="urn:ex:p" href=".g"/>
        <link about="urn:ex:s030" property="urn:ex:p" href="g.."/>
        <link about="urn:ex:s031" property="urn:ex:p" href="..g"/>
        <link about="urn:ex:s032" property="urn:ex:p" href="./../g"/>
        <link about="urn:ex:s033" property="urn:ex:p" href="./g/."/>
        <link about="urn:ex:s034" property="urn:ex:p" href="g/./h"/>
        <link about="urn:ex:s035" property="urn:ex:p" href="g/../h"/>
        <link about="urn:ex:s036" property="urn:ex:p" href="g;x=1/./y"/>
        <link about="urn:ex:s037" property="urn:ex:p" href="g;x=1/../y"/>
        <link about="urn:ex:s038" property="urn:ex:p" href="g?y/./x"/>
        <link about="urn:ex:s039" property="urn:ex:p" href="g?y/../x"/>
        <link about="urn:ex:s040" property="urn:ex:p" href="g#s/./x"/>
        <link about="urn:ex:s041" property="urn:ex:p" href="g#s/../x"/>
        <link about="urn:ex:s042" property="urn:ex:p" href="http:g"/>
      </div>

      <div xml:base="http://a/bb/ccc/d/">
        <!-- RFC3986 normal examples with trailing slash in base IRI -->
        <link about="urn:ex:s043" property="urn:ex:p" href="g:h"/>
        <link about="urn:ex:s044" property="urn:ex:p" href="g"/>
        <link about="urn:ex:s045" property="urn:ex:p" href="./g"/>
        <link about="urn:ex:s046" property="urn:ex:p" href="g/"/>
        <link about="urn:ex:s047" property="urn:ex:p" href="/g"/>
        <link about="urn:ex:s048" property="urn:ex:p" href="//g"/>
        <link about="urn:ex:s049" property="urn:ex:p" href="?y"/>
        <link about="urn:ex:s050" property="urn:ex:p" href="g?y"/>
        <link about="urn:ex:s051" property="urn:ex:p" href="#s"/>
        <link about="urn:ex:s052" property="urn:ex:p" href="g#s"/>
        <link about="urn:ex:s053" property="urn:ex:p" href="g?y#s"/>
        <link about="urn:ex:s054" property="urn:ex:p" href=";x"/>
        <link about="urn:ex:s055" property="urn:ex:p" href="g;x"/>
        <link about="urn:ex:s056" property="urn:ex:p" href="g;x?y#s"/>
        <link about="urn:ex:s057" property="urn:ex:p" href=""/>
        <link about="urn:ex:s058" property="urn:ex:p" href="."/>
        <link about="urn:ex:s059" property="urn:ex:p" href="./"/>
        <link about="urn:ex:s060" property="urn:ex:p" href=".."/>
        <link about="urn:ex:s061" property="urn:ex:p" href="../"/>
        <link about="urn:ex:s062" property="urn:ex:p" href="../g"/>
        <link about="urn:ex:s063" property="urn:ex:p" href="../.."/>
        <link about="urn:ex:s064" property="urn:ex:p" href="../../"/>
        <link about="urn:ex:s065" property="urn:ex:p" href="../../g"/>
      </div>

      <div xml:base="http://a/bb/ccc/d/">
        <!-- RFC3986 abnormal examples with trailing slash in base IRI -->
        <link about="urn:ex:s066" property="urn:ex:p" href="../../../g"/>
        <link about="urn:ex:s067" property="urn:ex:p" href="../../../../g"/>
        <link about="urn:ex:s068" property="urn:ex:p" href="/./g"/>
        <link about="urn:ex:s069" property="urn:ex:p" href="/../g"/>
        <link about="urn:ex:s070" property="urn:ex:p" href="g."/>
        <link about="urn:ex:s071" property="urn:ex:p" href=".g"/>
        <link about="urn:ex:s072" property="urn:ex:p" href="g.."/>
        <link about="urn:ex:s073" property="urn:ex:p" href="..g"/>
        <link about="urn:ex:s074" property="urn:ex:p" href="./../g"/>
        <link about="urn:ex:s075" property="urn:ex:p" href="./g/."/>
        <link about="urn:ex:s076" property="urn:ex:p" href="g/./h"/>
        <link about="urn:ex:s077" property="urn:ex:p" href="g/../h"/>
        <link about="urn:ex:s078" property="urn:ex:p" href="g;x=1/./y"/>
        <link about="urn:ex:s079" property="urn:ex:p" href="g;x=1/../y"/>
        <link about="urn:ex:s080" property="urn:ex:p" href="g?y/./x"/>
        <link about="urn:ex:s081" property="urn:ex:p" href="g?y/../x"/>
        <link about="urn:ex:s082" property="urn:ex:p" href="g#s/./x"/>
        <link about="urn:ex:s083" property="urn:ex:p" href="g#s/../x"/>
        <link about="urn:ex:s084" property="urn:ex:p" href="http:g"/>
      </div>

      <div xml:base="http://a/bb/ccc/./d;p?q">
        <!-- RFC3986 normal examples0 with ./ in the base IRI -->
        <link about="urn:ex:s085" property="urn:ex:p" href="g:h"/>
        <link about="urn:ex:s086" property="urn:ex:p" href="g"/>
        <link about="urn:ex:s087" property="urn:ex:p" href="./g"/>
        <link about="urn:ex:s088" property="urn:ex:p" href="g/"/>
        <link about="urn:ex:s089" property="urn:ex:p" href="/g"/>
        <link about="urn:ex:s090" property="urn:ex:p" href="//g"/>
        <link about="urn:ex:s091" property="urn:ex:p" href="?y"/>
        <link about="urn:ex:s092" property="urn:ex:p" href="g?y"/>
        <link about="urn:ex:s093" property="urn:ex:p" href="#s"/>
        <link about="urn:ex:s094" property="urn:ex:p" href="g#s"/>
        <link about="urn:ex:s095" property="urn:ex:p" href="g?y#s"/>
        <link about="urn:ex:s096" property="urn:ex:p" href=";x"/>
        <link about="urn:ex:s097" property="urn:ex:p" href="g;x"/>
        <link about="urn:ex:s098" property="urn:ex:p" href="g;x?y#s"/>
        <link about="urn:ex:s099" property="urn:ex:p" href=""/>
        <link about="urn:ex:s100" property="urn:ex:p" href="."/>
        <link about="urn:ex:s101" property="urn:ex:p" href="./"/>
        <link about="urn:ex:s102" property="urn:ex:p" href=".."/>
        <link about="urn:ex:s103" property="urn:ex:p" href="../"/>
        <link about="urn:ex:s104" property="urn:ex:p" href="../g"/>
        <link about="urn:ex:s105" property="urn:ex:p" href="../.."/>
        <link about="urn:ex:s106" property="urn:ex:p" href="../../"/>
        <link about="urn:ex:s107" property="urn:ex:p" href="../../g"/>
      </div>

      <div xml:base="http://a/bb/ccc/./d;p?q">
        <!-- RFC3986 abnormal examples with ./ in the base IRI -->
        <link about="urn:ex:s108" property="urn:ex:p" href="../../../g"/>
        <link about="urn:ex:s109" property="urn:ex:p" href="../../../../g"/>
        <link about="urn:ex:s110" property="urn:ex:p" href="/./g"/>
        <link about="urn:ex:s111" property="urn:ex:p" href="/../g"/>
        <link about="urn:ex:s112" property="urn:ex:p" href="g."/>
        <link about="urn:ex:s113" property="urn:ex:p" href=".g"/>
        <link about="urn:ex:s114" property="urn:ex:p" href="g.."/>
        <link about="urn:ex:s115" property="urn:ex:p" href="..g"/>
        <link about="urn:ex:s116" property="urn:ex:p" href="./../g"/>
        <link about="urn:ex:s117" property="urn:ex:p" href="./g/."/>
        <link about="urn:ex:s118" property="urn:ex:p" href="g/./h"/>
        <link about="urn:ex:s119" property="urn:ex:p" href="g/../h"/>
        <link about="urn:ex:s120" property="urn:ex:p" href="g;x=1/./y"/>
        <link about="urn:ex:s121" property="urn:ex:p" href="g;x=1/../y"/>
        <link about="urn:ex:s122" property="urn:ex:p" href="g?y/./x"/>
        <link about="urn:ex:s123" property="urn:ex:p" href="g?y/../x"/>
        <link about="urn:ex:s124" property="urn:ex:p" href="g#s/./x"/>
        <link about="urn:ex:s125" property="urn:ex:p" href="g#s/../x"/>
        <link about="urn:ex:s126" property="urn:ex:p" href="http:g"/>
      </div>

      <div xml:base="http://a/bb/ccc/../d;p?q">
        <!-- RFC3986 normal examples with ../ in the base IRI -->
        <link about="urn:ex:s127" property="urn:ex:p" href="g:h"/>
        <link about="urn:ex:s128" property="urn:ex:p" href="g"/>
        <link about="urn:ex:s129" property="urn:ex:p" href="./g"/>
        <link about="urn:ex:s130" property="urn:ex:p" href="g/"/>
        <link about="urn:ex:s131" property="urn:ex:p" href="/g"/>
        <link about="urn:ex:s132" property="urn:ex:p" href="//g"/>
        <link about="urn:ex:s133" property="urn:ex:p" href="?y"/>
        <link about="urn:ex:s134" property="urn:ex:p" href="g?y"/>
        <link about="urn:ex:s135" property="urn:ex:p" href="#s"/>
        <link about="urn:ex:s136" property="urn:ex:p" href="g#s"/>
        <link about="urn:ex:s137" property="urn:ex:p" href="g?y#s"/>
        <link about="urn:ex:s138" property="urn:ex:p" href=";x"/>
        <link about="urn:ex:s139" property="urn:ex:p" href="g;x"/>
        <link about="urn:ex:s140" property="urn:ex:p" href="g;x?y#s"/>
        <link about="urn:ex:s141" property="urn:ex:p" href=""/>
        <link about="urn:ex:s142" property="urn:ex:p" href="."/>
        <link about="urn:ex:s143" property="urn:ex:p" href="./"/>
        <link about="urn:ex:s144" property="urn:ex:p" href=".."/>
        <link about="urn:ex:s145" property="urn:ex:p" href="../"/>
        <link about="urn:ex:s146" property="urn:ex:p" href="../g"/>
        <link about="urn:ex:s147" property="urn:ex:p" href="../.."/>
        <link about="urn:ex:s148" property="urn:ex:p" href="../../"/>
        <link about="urn:ex:s149" property="urn:ex:p" href="../../g"/>
      </div>

      <div xml:base="http://a/bb/ccc/../d;p?q">
        <!-- RFC3986 abnormal examples with ../ in the base IRI -->
        <link about="urn:ex:s150" property="urn:ex:p" href="../../../g"/>
        <link about="urn:ex:s151" property="urn:ex:p" href="../../../../g"/>
        <link about="urn:ex:s152" property="urn:ex:p" href="/./g"/>
        <link about="urn:ex:s153" property="urn:ex:p" href="/../g"/>
        <link about="urn:ex:s154" property="urn:ex:p" href="g."/>
        <link about="urn:ex:s155" property="urn:ex:p" href=".g"/>
        <link about="urn:ex:s156" property="urn:ex:p" href="g.."/>
        <link about="urn:ex:s157" property="urn:ex:p" href="..g"/>
        <link about="urn:ex:s158" property="urn:ex:p" href="./../g"/>
        <link about="urn:ex:s159" property="urn:ex:p" href="./g/."/>
        <link about="urn:ex:s160" property="urn:ex:p" href="g/./h"/>
        <link about="urn:ex:s161" property="urn:ex:p" href="g/../h"/>
        <link about="urn:ex:s162" property="urn:ex:p" href="g;x=1/./y"/>
        <link about="urn:ex:s163" property="urn:ex:p" href="g;x=1/../y"/>
        <link about="urn:ex:s164" property="urn:ex:p" href="g?y/./x"/>
        <link about="urn:ex:s165" property="urn:ex:p" href="g?y/../x"/>
        <link about="urn:ex:s166" property="urn:ex:p" href="g#s/./x"/>
        <link about="urn:ex:s167" property="urn:ex:p" href="g#s/../x"/>
        <link about="urn:ex:s168" property="urn:ex:p" href="http:g"/>
      </div>

      <div xml:base="http://a/bb/ccc/.">
        <!-- RFC3986 normal examples with trailing ./ in the base IRI -->
        <link about="urn:ex:s169" property="urn:ex:p" href="g:h"/>
        <link about="urn:ex:s170" property="urn:ex:p" href="g"/>
        <link about="urn:ex:s171" property="urn:ex:p" href="./g"/>
        <link about="urn:ex:s172" property="urn:ex:p" href="g/"/>
        <link about="urn:ex:s173" property="urn:ex:p" href="/g"/>
        <link about="urn:ex:s174" property="urn:ex:p" href="//g"/>
        <link about="urn:ex:s175" property="urn:ex:p" href="?y"/>
        <link about="urn:ex:s176" property="urn:ex:p" href="g?y"/>
        <link about="urn:ex:s177" property="urn:ex:p" href="#s"/>
        <link about="urn:ex:s178" property="urn:ex:p" href="g#s"/>
        <link about="urn:ex:s179" property="urn:ex:p" href="g?y#s"/>
        <link about="urn:ex:s180" property="urn:ex:p" href=";x"/>
        <link about="urn:ex:s181" property="urn:ex:p" href="g;x"/>
        <link about="urn:ex:s182" property="urn:ex:p" href="g;x?y#s"/>
        <link about="urn:ex:s183" property="urn:ex:p" href=""/>
        <link about="urn:ex:s184" property="urn:ex:p" href="."/>
        <link about="urn:ex:s185" property="urn:ex:p" href="./"/>
        <link about="urn:ex:s186" property="urn:ex:p" href=".."/>
        <link about="urn:ex:s187" property="urn:ex:p" href="../"/>
        <link about="urn:ex:s188" property="urn:ex:p" href="../g"/>
        <link about="urn:ex:s189" property="urn:ex:p" href="../.."/>
        <link about="urn:ex:s190" property="urn:ex:p" href="../../"/>
        <link about="urn:ex:s191" property="urn:ex:p" href="../../g"/>
      </div>

      <div xml:base="http://a/bb/ccc/.">
        <!-- RFC3986 abnormal examples with trailing ./ in the base IRI -->
        <link about="urn:ex:s192" property="urn:ex:p" href="../../../g"/>
        <link about="urn:ex:s193" property="urn:ex:p" href="../../../../g"/>
        <link about="urn:ex:s194" property="urn:ex:p" href="/./g"/>
        <link about="urn:ex:s195" property="urn:ex:p" href="/../g"/>
        <link about="urn:ex:s196" property="urn:ex:p" href="g."/>
        <link about="urn:ex:s197" property="urn:ex:p" href=".g"/>
        <link about="urn:ex:s198" property="urn:ex:p" href="g.."/>
        <link about="urn:ex:s199" property="urn:ex:p" href="..g"/>
        <link about="urn:ex:s200" property="urn:ex:p" href="./../g"/>
        <link about="urn:ex:s201" property="urn:ex:p" href="./g/."/>
        <link about="urn:ex:s202" property="urn:ex:p" href="g/./h"/>
        <link about="urn:ex:s203" property="urn:ex:p" href="g/../h"/>
        <link about="urn:ex:s204" property="urn:ex:p" href="g;x=1/./y"/>
        <link about="urn:ex:s205" property="urn:ex:p" href="g;x=1/../y"/>
        <link about="urn:ex:s206" property="urn:ex:p" href="g?y/./x"/>
        <link about="urn:ex:s207" property="urn:ex:p" href="g?y/../x"/>
        <link about="urn:ex:s208" property="urn:ex:p" href="g#s/./x"/>
        <link about="urn:ex:s209" property="urn:ex:p" href="g#s/../x"/>
        <link about="urn:ex:s210" property="urn:ex:p" href="http:g"/>
      </div>

      <div xml:base="http://a/bb/ccc/..">
        <!-- RFC3986 normal examples with trailing ../ in the base IRI -->
        <link about="urn:ex:s211" property="urn:ex:p" href="g:h"/>
        <link about="urn:ex:s212" property="urn:ex:p" href="g"/>
        <link about="urn:ex:s213" property="urn:ex:p" href="./g"/>
        <link about="urn:ex:s214" property="urn:ex:p" href="g/"/>
        <link about="urn:ex:s215" property="urn:ex:p" href="/g"/>
        <link about="urn:ex:s216" property="urn:ex:p" href="//g"/>
        <link about="urn:ex:s217" property="urn:ex:p" href="?y"/>
        <link about="urn:ex:s218" property="urn:ex:p" href="g?y"/>
        <link about="urn:ex:s219" property="urn:ex:p" href="#s"/>
        <link about="urn:ex:s220" property="urn:ex:p" href="g#s"/>
        <link about="urn:ex:s221" property="urn:ex:p" href="g?y#s"/>
        <link about="urn:ex:s222" property="urn:ex:p" href=";x"/>
        <link about="urn:ex:s223" property="urn:ex:p" href="g;x"/>
        <link about="urn:ex:s224" property="urn:ex:p" href="g;x?y#s"/>
        <link about="urn:ex:s225" property="urn:ex:p" href=""/>
        <link about="urn:ex:s226" property="urn:ex:p" href="."/>
        <link about="urn:ex:s227" property="urn:ex:p" href="./"/>
        <link about="urn:ex:s228" property="urn:ex:p" href=".."/>
        <link about="urn:ex:s229" property="urn:ex:p" href="../"/>
        <link about="urn:ex:s230" property="urn:ex:p" href="../g"/>
        <link about="urn:ex:s231" property="urn:ex:p" href="../.."/>
        <link about="urn:ex:s232" property="urn:ex:p" href="../../"/>
        <link about="urn:ex:s233" property="urn:ex:p" href="../../g"/>
        <link about="urn:ex:s210" property="urn:ex:p" href="http:g"/>
      </div>

      <div xml:base="http://a/bb/ccc/..">
        <!-- RFC3986 abnormal examples with trailing ../ in the base IRI -->
        <link about="urn:ex:s234" property="urn:ex:p" href="../../../g"/>
        <link about="urn:ex:s235" property="urn:ex:p" href="../../../../g"/>
        <link about="urn:ex:s236" property="urn:ex:p" href="/./g"/>
        <link about="urn:ex:s237" property="urn:ex:p" href="/../g"/>
        <link about="urn:ex:s238" property="urn:ex:p" href="g."/>
        <link about="urn:ex:s239" property="urn:ex:p" href=".g"/>
        <link about="urn:ex:s240" property="urn:ex:p" href="g.."/>
        <link about="urn:ex:s241" property="urn:ex:p" href="..g"/>
        <link about="urn:ex:s242" property="urn:ex:p" href="./../g"/>
        <link about="urn:ex:s243" property="urn:ex:p" href="./g/."/>
        <link about="urn:ex:s244" property="urn:ex:p" href="g/./h"/>
        <link about="urn:ex:s245" property="urn:ex:p" href="g/../h"/>
        <link about="urn:ex:s246" property="urn:ex:p" href="g;x=1/./y"/>
        <link about="urn:ex:s247" property="urn:ex:p" href="g;x=1/../y"/>
        <link about="urn:ex:s248" property="urn:ex:p" href="g?y/./x"/>
        <link about="urn:ex:s249" property="urn:ex:p" href="g?y/../x"/>
        <link about="urn:ex:s250" property="urn:ex:p" href="g#s/./x"/>
        <link about="urn:ex:s251" property="urn:ex:p" href="g#s/../x"/>
        <link about="urn:ex:s252" property="urn:ex:p" href="http:g"/>
      </div>

      <div xml:base="file:///a/bb/ccc/d;p?q">
        <!-- RFC3986 normal examples with file path -->
        <link about="urn:ex:s253" property="urn:ex:p" href="g:h"/>
        <link about="urn:ex:s254" property="urn:ex:p" href="g"/>
        <link about="urn:ex:s255" property="urn:ex:p" href="./g"/>
        <link about="urn:ex:s256" property="urn:ex:p" href="g/"/>
        <link about="urn:ex:s257" property="urn:ex:p" href="/g"/>
        <link about="urn:ex:s258" property="urn:ex:p" href="//g"/>
        <link about="urn:ex:s259" property="urn:ex:p" href="?y"/>
        <link about="urn:ex:s260" property="urn:ex:p" href="g?y"/>
        <link about="urn:ex:s261" property="urn:ex:p" href="#s"/>
        <link about="urn:ex:s262" property="urn:ex:p" href="g#s"/>
        <link about="urn:ex:s263" property="urn:ex:p" href="g?y#s"/>
        <link about="urn:ex:s264" property="urn:ex:p" href=";x"/>
        <link about="urn:ex:s265" property="urn:ex:p" href="g;x"/>
        <link about="urn:ex:s266" property="urn:ex:p" href="g;x?y#s"/>
        <link about="urn:ex:s267" property="urn:ex:p" href=""/>
        <link about="urn:ex:s268" property="urn:ex:p" href="."/>
        <link about="urn:ex:s269" property="urn:ex:p" href="./"/>
        <link about="urn:ex:s270" property="urn:ex:p" href=".."/>
        <link about="urn:ex:s271" property="urn:ex:p" href="../"/>
        <link about="urn:ex:s272" property="urn:ex:p" href="../g"/>
        <link about="urn:ex:s273" property="urn:ex:p" href="../.."/>
        <link about="urn:ex:s274" property="urn:ex:p" href="../../"/>
        <link about="urn:ex:s275" property="urn:ex:p" href="../../g"/>
      </div>

      <div xml:base="file:///a/bb/ccc/d;p?q">
        <!-- RFC3986 abnormal examples with file path -->
        <link about="urn:ex:s276" property="urn:ex:p" href="../../../g"/>
        <link about="urn:ex:s277" property="urn:ex:p" href="../../../../g"/>
        <link about="urn:ex:s278" property="urn:ex:p" href="/./g"/>
        <link about="urn:ex:s279" property="urn:ex:p" href="/../g"/>
        <link about="urn:ex:s280" property="urn:ex:p" href="g."/>
        <link about="urn:ex:s281" property="urn:ex:p" href=".g"/>
        <link about="urn:ex:s282" property="urn:ex:p" href="g.."/>
        <link about="urn:ex:s283" property="urn:ex:p" href="..g"/>
        <link about="urn:ex:s284" property="urn:ex:p" href="./../g"/>
        <link about="urn:ex:s285" property="urn:ex:p" href="./g/."/>
        <link about="urn:ex:s286" property="urn:ex:p" href="g/./h"/>
        <link about="urn:ex:s287" property="urn:ex:p" href="g/../h"/>
        <link about="urn:ex:s288" property="urn:ex:p" href="g;x=1/./y"/>
        <link about="urn:ex:s289" property="urn:ex:p" href="g;x=1/../y"/>
        <link about="urn:ex:s290" property="urn:ex:p" href="g?y/./x"/>
        <link about="urn:ex:s291" property="urn:ex:p" href="g?y/../x"/>
        <link about="urn:ex:s292" property="urn:ex:p" href="g#s/./x"/>
        <link about="urn:ex:s293" property="urn:ex:p" href="g#s/../x"/>
        <link about="urn:ex:s294" property="urn:ex:p" href="http:g"/>
      </div>

      <!-- additional cases -->
      <div xml:base="http://abc/def/ghi">
        <link about="urn:ex:s295" property="urn:ex:p" href="."/>
        <link about="urn:ex:s296" property="urn:ex:p" href=".?a=b"/>
        <link about="urn:ex:s297" property="urn:ex:p" href=".#a=b"/>
        <link about="urn:ex:s298" property="urn:ex:p" href=".."/>
        <link about="urn:ex:s299" property="urn:ex:p" href="..?a=b"/>
        <link about="urn:ex:s300" property="urn:ex:p" href="..#a=b"/>
      </div>
      <div xml:base="http://ab//de//ghi">
        <link about="urn:ex:s301" property="urn:ex:p" href="xyz"/>
        <link about="urn:ex:s302" property="urn:ex:p" href="./xyz"/>
        <link about="urn:ex:s303" property="urn:ex:p" href="../xyz"/>
      </div>
      <div xml:base="http://abc/d:f/ghi">
        <link about="urn:ex:s304" property="urn:ex:p" href="xyz"/>
        <link about="urn:ex:s305" property="urn:ex:p" href="./xyz"/>
        <link about="urn:ex:s306" property="urn:ex:p" href="../xyz"/>
      </div>
    </body></html>}}
    let(:nt) {%q{
      # RFC3986 normal examples

      <urn:ex:s001> <urn:ex:p> <g:h>.
      <urn:ex:s002> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s003> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s004> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s005> <urn:ex:p> <http://a/g>.
      <urn:ex:s006> <urn:ex:p> <http://g>.
      <urn:ex:s007> <urn:ex:p> <http://a/bb/ccc/d;p?y>.
      <urn:ex:s008> <urn:ex:p> <http://a/bb/ccc/g?y>.
      <urn:ex:s009> <urn:ex:p> <http://a/bb/ccc/d;p?q#s>.
      <urn:ex:s010> <urn:ex:p> <http://a/bb/ccc/g#s>.
      <urn:ex:s011> <urn:ex:p> <http://a/bb/ccc/g?y#s>.
      <urn:ex:s012> <urn:ex:p> <http://a/bb/ccc/;x>.
      <urn:ex:s013> <urn:ex:p> <http://a/bb/ccc/g;x>.
      <urn:ex:s014> <urn:ex:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:ex:s015> <urn:ex:p> <http://a/bb/ccc/d;p?q>.
      <urn:ex:s016> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s017> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s018> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s019> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s020> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s021> <urn:ex:p> <http://a/>.
      <urn:ex:s022> <urn:ex:p> <http://a/>.
      <urn:ex:s023> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples

      <urn:ex:s024> <urn:ex:p> <http://a/g>.
      <urn:ex:s025> <urn:ex:p> <http://a/g>.
      <urn:ex:s026> <urn:ex:p> <http://a/g>.
      <urn:ex:s027> <urn:ex:p> <http://a/g>.
      <urn:ex:s028> <urn:ex:p> <http://a/bb/ccc/g.>.
      <urn:ex:s029> <urn:ex:p> <http://a/bb/ccc/.g>.
      <urn:ex:s030> <urn:ex:p> <http://a/bb/ccc/g..>.
      <urn:ex:s031> <urn:ex:p> <http://a/bb/ccc/..g>.
      <urn:ex:s032> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s033> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s034> <urn:ex:p> <http://a/bb/ccc/g/h>.
      <urn:ex:s035> <urn:ex:p> <http://a/bb/ccc/h>.
      <urn:ex:s036> <urn:ex:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:ex:s037> <urn:ex:p> <http://a/bb/ccc/y>.
      <urn:ex:s038> <urn:ex:p> <http://a/bb/ccc/g?y/./x>.
      <urn:ex:s039> <urn:ex:p> <http://a/bb/ccc/g?y/../x>.
      <urn:ex:s040> <urn:ex:p> <http://a/bb/ccc/g#s/./x>.
      <urn:ex:s041> <urn:ex:p> <http://a/bb/ccc/g#s/../x>.
      <urn:ex:s042> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with trailing slash in base IRI

      <urn:ex:s043> <urn:ex:p> <g:h>.
      <urn:ex:s044> <urn:ex:p> <http://a/bb/ccc/d/g>.
      <urn:ex:s045> <urn:ex:p> <http://a/bb/ccc/d/g>.
      <urn:ex:s046> <urn:ex:p> <http://a/bb/ccc/d/g/>.
      <urn:ex:s047> <urn:ex:p> <http://a/g>.
      <urn:ex:s048> <urn:ex:p> <http://g>.
      <urn:ex:s049> <urn:ex:p> <http://a/bb/ccc/d/?y>.
      <urn:ex:s050> <urn:ex:p> <http://a/bb/ccc/d/g?y>.
      <urn:ex:s051> <urn:ex:p> <http://a/bb/ccc/d/#s>.
      <urn:ex:s052> <urn:ex:p> <http://a/bb/ccc/d/g#s>.
      <urn:ex:s053> <urn:ex:p> <http://a/bb/ccc/d/g?y#s>.
      <urn:ex:s054> <urn:ex:p> <http://a/bb/ccc/d/;x>.
      <urn:ex:s055> <urn:ex:p> <http://a/bb/ccc/d/g;x>.
      <urn:ex:s056> <urn:ex:p> <http://a/bb/ccc/d/g;x?y#s>.
      <urn:ex:s057> <urn:ex:p> <http://a/bb/ccc/d/>.
      <urn:ex:s058> <urn:ex:p> <http://a/bb/ccc/d/>.
      <urn:ex:s059> <urn:ex:p> <http://a/bb/ccc/d/>.
      <urn:ex:s060> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s061> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s062> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s063> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s064> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s065> <urn:ex:p> <http://a/bb/g>.

      # RFC3986 abnormal examples with trailing slash in base IRI

      <urn:ex:s066> <urn:ex:p> <http://a/g>.
      <urn:ex:s067> <urn:ex:p> <http://a/g>.
      <urn:ex:s068> <urn:ex:p> <http://a/g>.
      <urn:ex:s069> <urn:ex:p> <http://a/g>.
      <urn:ex:s070> <urn:ex:p> <http://a/bb/ccc/d/g.>.
      <urn:ex:s071> <urn:ex:p> <http://a/bb/ccc/d/.g>.
      <urn:ex:s072> <urn:ex:p> <http://a/bb/ccc/d/g..>.
      <urn:ex:s073> <urn:ex:p> <http://a/bb/ccc/d/..g>.
      <urn:ex:s074> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s075> <urn:ex:p> <http://a/bb/ccc/d/g/>.
      <urn:ex:s076> <urn:ex:p> <http://a/bb/ccc/d/g/h>.
      <urn:ex:s077> <urn:ex:p> <http://a/bb/ccc/d/h>.
      <urn:ex:s078> <urn:ex:p> <http://a/bb/ccc/d/g;x=1/y>.
      <urn:ex:s079> <urn:ex:p> <http://a/bb/ccc/d/y>.
      <urn:ex:s080> <urn:ex:p> <http://a/bb/ccc/d/g?y/./x>.
      <urn:ex:s081> <urn:ex:p> <http://a/bb/ccc/d/g?y/../x>.
      <urn:ex:s082> <urn:ex:p> <http://a/bb/ccc/d/g#s/./x>.
      <urn:ex:s083> <urn:ex:p> <http://a/bb/ccc/d/g#s/../x>.
      <urn:ex:s084> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with /. in the base IRI

      <urn:ex:s085> <urn:ex:p> <g:h>.
      <urn:ex:s086> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s087> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s088> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s089> <urn:ex:p> <http://a/g>.
      <urn:ex:s090> <urn:ex:p> <http://g>.
      <urn:ex:s091> <urn:ex:p> <http://a/bb/ccc/./d;p?y>.
      <urn:ex:s092> <urn:ex:p> <http://a/bb/ccc/g?y>.
      <urn:ex:s093> <urn:ex:p> <http://a/bb/ccc/./d;p?q#s>.
      <urn:ex:s094> <urn:ex:p> <http://a/bb/ccc/g#s>.
      <urn:ex:s095> <urn:ex:p> <http://a/bb/ccc/g?y#s>.
      <urn:ex:s096> <urn:ex:p> <http://a/bb/ccc/;x>.
      <urn:ex:s097> <urn:ex:p> <http://a/bb/ccc/g;x>.
      <urn:ex:s098> <urn:ex:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:ex:s099> <urn:ex:p> <http://a/bb/ccc/./d;p?q>.
      <urn:ex:s100> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s101> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s102> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s103> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s104> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s105> <urn:ex:p> <http://a/>.
      <urn:ex:s106> <urn:ex:p> <http://a/>.
      <urn:ex:s107> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples with /. in the base IRI

      <urn:ex:s108> <urn:ex:p> <http://a/g>.
      <urn:ex:s109> <urn:ex:p> <http://a/g>.
      <urn:ex:s110> <urn:ex:p> <http://a/g>.
      <urn:ex:s111> <urn:ex:p> <http://a/g>.
      <urn:ex:s112> <urn:ex:p> <http://a/bb/ccc/g.>.
      <urn:ex:s113> <urn:ex:p> <http://a/bb/ccc/.g>.
      <urn:ex:s114> <urn:ex:p> <http://a/bb/ccc/g..>.
      <urn:ex:s115> <urn:ex:p> <http://a/bb/ccc/..g>.
      <urn:ex:s116> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s117> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s118> <urn:ex:p> <http://a/bb/ccc/g/h>.
      <urn:ex:s119> <urn:ex:p> <http://a/bb/ccc/h>.
      <urn:ex:s120> <urn:ex:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:ex:s121> <urn:ex:p> <http://a/bb/ccc/y>.
      <urn:ex:s122> <urn:ex:p> <http://a/bb/ccc/g?y/./x>.
      <urn:ex:s123> <urn:ex:p> <http://a/bb/ccc/g?y/../x>.
      <urn:ex:s124> <urn:ex:p> <http://a/bb/ccc/g#s/./x>.
      <urn:ex:s125> <urn:ex:p> <http://a/bb/ccc/g#s/../x>.
      <urn:ex:s126> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with /.. in the base IRI

      <urn:ex:s127> <urn:ex:p> <g:h>.
      <urn:ex:s128> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s129> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s130> <urn:ex:p> <http://a/bb/g/>.
      <urn:ex:s131> <urn:ex:p> <http://a/g>.
      <urn:ex:s132> <urn:ex:p> <http://g>.
      <urn:ex:s133> <urn:ex:p> <http://a/bb/ccc/../d;p?y>.
      <urn:ex:s134> <urn:ex:p> <http://a/bb/g?y>.
      <urn:ex:s135> <urn:ex:p> <http://a/bb/ccc/../d;p?q#s>.
      <urn:ex:s136> <urn:ex:p> <http://a/bb/g#s>.
      <urn:ex:s137> <urn:ex:p> <http://a/bb/g?y#s>.
      <urn:ex:s138> <urn:ex:p> <http://a/bb/;x>.
      <urn:ex:s139> <urn:ex:p> <http://a/bb/g;x>.
      <urn:ex:s140> <urn:ex:p> <http://a/bb/g;x?y#s>.
      <urn:ex:s141> <urn:ex:p> <http://a/bb/ccc/../d;p?q>.
      <urn:ex:s142> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s143> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s144> <urn:ex:p> <http://a/>.
      <urn:ex:s145> <urn:ex:p> <http://a/>.
      <urn:ex:s146> <urn:ex:p> <http://a/g>.
      <urn:ex:s147> <urn:ex:p> <http://a/>.
      <urn:ex:s148> <urn:ex:p> <http://a/>.
      <urn:ex:s149> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples with /.. in the base IRI

      <urn:ex:s150> <urn:ex:p> <http://a/g>.
      <urn:ex:s151> <urn:ex:p> <http://a/g>.
      <urn:ex:s152> <urn:ex:p> <http://a/g>.
      <urn:ex:s153> <urn:ex:p> <http://a/g>.
      <urn:ex:s154> <urn:ex:p> <http://a/bb/g.>.
      <urn:ex:s155> <urn:ex:p> <http://a/bb/.g>.
      <urn:ex:s156> <urn:ex:p> <http://a/bb/g..>.
      <urn:ex:s157> <urn:ex:p> <http://a/bb/..g>.
      <urn:ex:s158> <urn:ex:p> <http://a/g>.
      <urn:ex:s159> <urn:ex:p> <http://a/bb/g/>.
      <urn:ex:s160> <urn:ex:p> <http://a/bb/g/h>.
      <urn:ex:s161> <urn:ex:p> <http://a/bb/h>.
      <urn:ex:s162> <urn:ex:p> <http://a/bb/g;x=1/y>.
      <urn:ex:s163> <urn:ex:p> <http://a/bb/y>.
      <urn:ex:s164> <urn:ex:p> <http://a/bb/g?y/./x>.
      <urn:ex:s165> <urn:ex:p> <http://a/bb/g?y/../x>.
      <urn:ex:s166> <urn:ex:p> <http://a/bb/g#s/./x>.
      <urn:ex:s167> <urn:ex:p> <http://a/bb/g#s/../x>.
      <urn:ex:s168> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with trailing /. in the base IRI

      <urn:ex:s169> <urn:ex:p> <g:h>.
      <urn:ex:s170> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s171> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s172> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s173> <urn:ex:p> <http://a/g>.
      <urn:ex:s174> <urn:ex:p> <http://g>.
      <urn:ex:s175> <urn:ex:p> <http://a/bb/ccc/.?y>.
      <urn:ex:s176> <urn:ex:p> <http://a/bb/ccc/g?y>.
      <urn:ex:s177> <urn:ex:p> <http://a/bb/ccc/.#s>.
      <urn:ex:s178> <urn:ex:p> <http://a/bb/ccc/g#s>.
      <urn:ex:s179> <urn:ex:p> <http://a/bb/ccc/g?y#s>.
      <urn:ex:s180> <urn:ex:p> <http://a/bb/ccc/;x>.
      <urn:ex:s181> <urn:ex:p> <http://a/bb/ccc/g;x>.
      <urn:ex:s182> <urn:ex:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:ex:s183> <urn:ex:p> <http://a/bb/ccc/.>.
      <urn:ex:s184> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s185> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s186> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s187> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s188> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s189> <urn:ex:p> <http://a/>.
      <urn:ex:s190> <urn:ex:p> <http://a/>.
      <urn:ex:s191> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples with trailing /. in the base IRI

      <urn:ex:s192> <urn:ex:p> <http://a/g>.
      <urn:ex:s193> <urn:ex:p> <http://a/g>.
      <urn:ex:s194> <urn:ex:p> <http://a/g>.
      <urn:ex:s195> <urn:ex:p> <http://a/g>.
      <urn:ex:s196> <urn:ex:p> <http://a/bb/ccc/g.>.
      <urn:ex:s197> <urn:ex:p> <http://a/bb/ccc/.g>.
      <urn:ex:s198> <urn:ex:p> <http://a/bb/ccc/g..>.
      <urn:ex:s199> <urn:ex:p> <http://a/bb/ccc/..g>.
      <urn:ex:s200> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s201> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s202> <urn:ex:p> <http://a/bb/ccc/g/h>.
      <urn:ex:s203> <urn:ex:p> <http://a/bb/ccc/h>.
      <urn:ex:s204> <urn:ex:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:ex:s205> <urn:ex:p> <http://a/bb/ccc/y>.
      <urn:ex:s206> <urn:ex:p> <http://a/bb/ccc/g?y/./x>.
      <urn:ex:s207> <urn:ex:p> <http://a/bb/ccc/g?y/../x>.
      <urn:ex:s208> <urn:ex:p> <http://a/bb/ccc/g#s/./x>.
      <urn:ex:s209> <urn:ex:p> <http://a/bb/ccc/g#s/../x>.
      <urn:ex:s210> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with trailing /.. in the base IRI

      <urn:ex:s211> <urn:ex:p> <g:h>.
      <urn:ex:s212> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s213> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s214> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s215> <urn:ex:p> <http://a/g>.
      <urn:ex:s216> <urn:ex:p> <http://g>.
      <urn:ex:s217> <urn:ex:p> <http://a/bb/ccc/..?y>.
      <urn:ex:s218> <urn:ex:p> <http://a/bb/ccc/g?y>.
      <urn:ex:s219> <urn:ex:p> <http://a/bb/ccc/..#s>.
      <urn:ex:s220> <urn:ex:p> <http://a/bb/ccc/g#s>.
      <urn:ex:s221> <urn:ex:p> <http://a/bb/ccc/g?y#s>.
      <urn:ex:s222> <urn:ex:p> <http://a/bb/ccc/;x>.
      <urn:ex:s223> <urn:ex:p> <http://a/bb/ccc/g;x>.
      <urn:ex:s224> <urn:ex:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:ex:s225> <urn:ex:p> <http://a/bb/ccc/..>.
      <urn:ex:s226> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s227> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s228> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s229> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s230> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s231> <urn:ex:p> <http://a/>.
      <urn:ex:s232> <urn:ex:p> <http://a/>.
      <urn:ex:s233> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples with trailing /.. in the base IRI

      <urn:ex:s234> <urn:ex:p> <http://a/g>.
      <urn:ex:s235> <urn:ex:p> <http://a/g>.
      <urn:ex:s236> <urn:ex:p> <http://a/g>.
      <urn:ex:s237> <urn:ex:p> <http://a/g>.
      <urn:ex:s238> <urn:ex:p> <http://a/bb/ccc/g.>.
      <urn:ex:s239> <urn:ex:p> <http://a/bb/ccc/.g>.
      <urn:ex:s240> <urn:ex:p> <http://a/bb/ccc/g..>.
      <urn:ex:s241> <urn:ex:p> <http://a/bb/ccc/..g>.
      <urn:ex:s242> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s243> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s244> <urn:ex:p> <http://a/bb/ccc/g/h>.
      <urn:ex:s245> <urn:ex:p> <http://a/bb/ccc/h>.
      <urn:ex:s246> <urn:ex:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:ex:s247> <urn:ex:p> <http://a/bb/ccc/y>.
      <urn:ex:s248> <urn:ex:p> <http://a/bb/ccc/g?y/./x>.
      <urn:ex:s249> <urn:ex:p> <http://a/bb/ccc/g?y/../x>.
      <urn:ex:s250> <urn:ex:p> <http://a/bb/ccc/g#s/./x>.
      <urn:ex:s251> <urn:ex:p> <http://a/bb/ccc/g#s/../x>.
      <urn:ex:s252> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with file path

      <urn:ex:s253> <urn:ex:p> <g:h>.
      <urn:ex:s254> <urn:ex:p> <file:///a/bb/ccc/g>.
      <urn:ex:s255> <urn:ex:p> <file:///a/bb/ccc/g>.
      <urn:ex:s256> <urn:ex:p> <file:///a/bb/ccc/g/>.
      <urn:ex:s257> <urn:ex:p> <file:///g>.
      <urn:ex:s258> <urn:ex:p> <file://g>.
      <urn:ex:s259> <urn:ex:p> <file:///a/bb/ccc/d;p?y>.
      <urn:ex:s260> <urn:ex:p> <file:///a/bb/ccc/g?y>.
      <urn:ex:s261> <urn:ex:p> <file:///a/bb/ccc/d;p?q#s>.
      <urn:ex:s262> <urn:ex:p> <file:///a/bb/ccc/g#s>.
      <urn:ex:s263> <urn:ex:p> <file:///a/bb/ccc/g?y#s>.
      <urn:ex:s264> <urn:ex:p> <file:///a/bb/ccc/;x>.
      <urn:ex:s265> <urn:ex:p> <file:///a/bb/ccc/g;x>.
      <urn:ex:s266> <urn:ex:p> <file:///a/bb/ccc/g;x?y#s>.
      <urn:ex:s267> <urn:ex:p> <file:///a/bb/ccc/d;p?q>.
      <urn:ex:s268> <urn:ex:p> <file:///a/bb/ccc/>.
      <urn:ex:s269> <urn:ex:p> <file:///a/bb/ccc/>.
      <urn:ex:s270> <urn:ex:p> <file:///a/bb/>.
      <urn:ex:s271> <urn:ex:p> <file:///a/bb/>.
      <urn:ex:s272> <urn:ex:p> <file:///a/bb/g>.
      <urn:ex:s273> <urn:ex:p> <file:///a/>.
      <urn:ex:s274> <urn:ex:p> <file:///a/>.
      <urn:ex:s275> <urn:ex:p> <file:///a/g>.

      # RFC3986 abnormal examples with file path

      <urn:ex:s276> <urn:ex:p> <file:///g>.
      <urn:ex:s277> <urn:ex:p> <file:///g>.
      <urn:ex:s278> <urn:ex:p> <file:///g>.
      <urn:ex:s279> <urn:ex:p> <file:///g>.
      <urn:ex:s280> <urn:ex:p> <file:///a/bb/ccc/g.>.
      <urn:ex:s281> <urn:ex:p> <file:///a/bb/ccc/.g>.
      <urn:ex:s282> <urn:ex:p> <file:///a/bb/ccc/g..>.
      <urn:ex:s283> <urn:ex:p> <file:///a/bb/ccc/..g>.
      <urn:ex:s284> <urn:ex:p> <file:///a/bb/g>.
      <urn:ex:s285> <urn:ex:p> <file:///a/bb/ccc/g/>.
      <urn:ex:s286> <urn:ex:p> <file:///a/bb/ccc/g/h>.
      <urn:ex:s287> <urn:ex:p> <file:///a/bb/ccc/h>.
      <urn:ex:s288> <urn:ex:p> <file:///a/bb/ccc/g;x=1/y>.
      <urn:ex:s289> <urn:ex:p> <file:///a/bb/ccc/y>.
      <urn:ex:s290> <urn:ex:p> <file:///a/bb/ccc/g?y/./x>.
      <urn:ex:s291> <urn:ex:p> <file:///a/bb/ccc/g?y/../x>.
      <urn:ex:s292> <urn:ex:p> <file:///a/bb/ccc/g#s/./x>.
      <urn:ex:s293> <urn:ex:p> <file:///a/bb/ccc/g#s/../x>.
      <urn:ex:s294> <urn:ex:p> <http:g>.

      # additional cases

      <urn:ex:s295> <urn:ex:p> <http://abc/def/>.
      <urn:ex:s296> <urn:ex:p> <http://abc/def/?a=b>.
      <urn:ex:s297> <urn:ex:p> <http://abc/def/#a=b>.
      <urn:ex:s298> <urn:ex:p> <http://abc/>.
      <urn:ex:s299> <urn:ex:p> <http://abc/?a=b>.
      <urn:ex:s300> <urn:ex:p> <http://abc/#a=b>.

      <urn:ex:s301> <urn:ex:p> <http://ab//de//xyz>.
      <urn:ex:s302> <urn:ex:p> <http://ab//de//xyz>.
      <urn:ex:s303> <urn:ex:p> <http://ab//de/xyz>.

      <urn:ex:s304> <urn:ex:p> <http://abc/d:f/xyz>.
      <urn:ex:s305> <urn:ex:p> <http://abc/d:f/xyz>.
      <urn:ex:s306> <urn:ex:p> <http://abc/xyz>.
    }}
    it "produces equivalent triples" do
      nt_str = RDF::NTriples::Reader.new(nt).dump(:ntriples).split("\n").sort.join("\n")
      html_str = RDF::RDFa::Reader.new(html, host_language: :xhtml5).dump(:ntriples).split("\n").sort.join("\n")
      expect(html_str).to eql(nt_str)
    end
  end

  def parse(input, options = {})
    graph = RDF::Graph.new
    RDF::RDFa::Reader.new(input, options.merge(logger: logger, library: @library)).each do |statement|
      graph << statement rescue fail "SPEC: #{$!}"
    end
    graph
  end

end
