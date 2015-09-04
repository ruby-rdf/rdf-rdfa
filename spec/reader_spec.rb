$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

describe "RDF::RDFa::Reader" do
  let!(:doap) {File.expand_path("../../etc/doap.html", __FILE__)}
  let!(:doap_nt) {File.expand_path("../../etc/doap.nt", __FILE__)}

  # @see lib/rdf/spec/reader.rb in rdf-spec
  it_behaves_like 'an RDF::Reader' do
    let(:reader_input) {File.read(doap)}
    let(:reader) {RDF::RDFa::Reader.new(reader_input)}
    let(:reader_count) {File.open(doap_nt).each_line.to_a.length}
  end

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
      RDF::RDFa::Reader.new(subject) do |reader|
        inner.called(reader.class)
      end
    end

    it "returns reader" do
      expect(RDF::RDFa::Reader.new(subject)).to be_a(RDF::RDFa::Reader)
    end

    it "yiels statements" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::Statement)
      RDF::RDFa::Reader.new(subject).each_statement do |statement|
        inner.called(statement.class)
      end
    end

    it "yelds triples" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::URI, RDF::URI, RDF::Literal)
      RDF::RDFa::Reader.new(subject).each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
    
    it "calls Proc with processor statements for :processor_callback" do
      lam = double("lambda")
      expect(lam).to receive(:call).at_least(1) {|s| expect(s).to be_statement}
      RDF::RDFa::Reader.new(subject, :processor_callback => lam).each_triple {}
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
        expect(parse(source)).to pass_query(output, :trace => @debug)
      end

      it "generates output graph with rdfagraph=output" do
        expect(parse(source, :rdfagraph => :output)).to pass_query(output, :trace => @debug)
        expect(parse(source, :rdfagraph => :output)).not_to pass_query(processor, :trace => @debug)
      end

      it "generates output graph with rdfagraph=[output]" do
        expect(parse(source, :rdfagraph => [:output])).to pass_query(output, :trace => @debug)
      end

      it "generates output graph with rdfagraph=foo" do
        expect(parse(source, :rdfagraph => :foo)).to pass_query(output, :trace => @debug)
      end

      it "generates processor graph with rdfagraph=processor" do
        expect(parse(source, :rdfagraph => :processor)).to pass_query(processor, :trace => @debug)
        expect(parse(source, :rdfagraph => :processor)).not_to pass_query(output, :trace => @debug)
      end

      it "generates both output and processor graphs with rdfagraph=[output,processor]" do
        expect(parse(source, :rdfagraph => [:output, :processor])).to pass_query(output, :trace => @debug)
        expect(parse(source, :rdfagraph => [:output, :processor])).to pass_query(processor, :trace => @debug)
      end

      it "generates both output and processor graphs with rdfagraph=output,processor" do
        expect(parse(source, :rdfagraph => "output, processor")).to pass_query(output, :trace => @debug)
        expect(parse(source, :rdfagraph => "output, processor")).to pass_query(processor, :trace => @debug)
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

          expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug)
        end
      end

      context :features do
        describe "XML Literal", :not_jruby => true do
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
            expected = %q(
              @base <http://example/> .
              @prefix dc: <http://purl.org/dc/terms/> .
              @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

              <> dc:title "E = mc<sup xmlns=\"http://www.w3.org/1999/xhtml\">2</sup>: The Most Urgent Problem of Our Time"^^rdf:XMLLiteral .
            )

            expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug)
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
            expected = %q(
              @base <http://example/> .
              @prefix dc: <http://purl.org/dc/terms/> .
              @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

              <> dc:title "E = mc<sup>2</sup>: The Most Urgent Problem of Our Time"^^rdf:HTML .
            )

            expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug)
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

          expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug)
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
            expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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
            expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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
            expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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
            expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
          end

          it "uses @resource as subject of child elements" do
            html = %(
              <div resource="foo"><span property="dc:title">Title</span></div>
            )
            expected = RDF::Graph.new << RDF::Statement.new(RDF::URI("foo"), RDF::DC.title, "Title")
            expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
          end

          context :SafeCURIEorCURIEorIRI do
            {
              :term => [
                %(<link about="" property="rdf:value" resource="describedby"/>),
                %q(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                  @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                  <> rdf:value <describedby> .
                )
              ],
              :curie => [
                %(<link about="" property="rdf:value" resource="xhv:describedby"/>),
                %q(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                  @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                  <> rdf:value xhv:describedby .
                )
              ],
              :save_curie => [
                %(<link about="" property="rdf:value" resource="[xhv:describedby]"/>),
                %q(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                  @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                  <> rdf:value xhv:describedby .
                )
              ],
            }.each do |test, (input, expected)|
              it "expands #{test}" do
                expect(parse(input)).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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
            expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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
              expect(parse(subject, :version => "rdfa1.0")).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
            end
          end
      
          context "RDFa 1.1" do
            it "creates a statement with object from @src" do
              expected = RDF::Graph.new <<
                RDF::Statement.new(RDF::URI("foo"), RDF.value, RDF::URI("bar")) <<
                RDF::Statement.new(RDF::URI("foo"), RDF::DC.title, "Title")
              expect(parse(subject)).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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

            expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug)
          end
          
          it "empty @typeof on root" do
            html = %(<html typeof=""><span property="dc:title">Title</span></html>)
            expected = RDF::Graph.new << RDF::Statement.new(RDF::URI(""), RDF::DC.title, "Title")

            expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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

          expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
        end

        describe "xml:base" do
          {
            :xml => true,
            :xhtml1 => false,
            :html4 => false,
            :html5 => false,
            :xhtml5 => true,
            :svg => true
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

                expect(parse(html, :base_uri => "http://example/doc_base",
                  :version => :"rdfa1.1",
                  :host_language => hl
                )).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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

                expect(parse(html, :base_uri => "http://example/doc_base",
                  :version => :"rdfa1.1",
                  :host_language => hl
                )).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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
              expect(parse("<html>#{html}</html>", :version => :"rdfa1.1")).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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
                    expect(parse(@rdfa, :validate => false)).to be_equivalent_graph(@expected, :trace => @debug)
                  end
            
                  it "does not create triple when validating" do
                    expect {parse(@rdfa, :validate => true)}.to raise_error(RDF::ReaderError)
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
            expect(parse(html)).to be_equivalent_graph(expected, :trace => @debug)
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
            expect(parse(subject)).to pass_query(query, @debug)
          end

          it "uses vocabulary when creating type IRI" do
            query = %q(
              PREFIX foaf: <http://xmlns.com/foaf/0.1/>
              ASK WHERE { <http://example/#me> foaf:name "Gregg Kellogg" }
            )
            expect(parse(subject)).to pass_query(query, @debug)
          end

          it "adds rdfa:hasProperty triple" do
            query = %q(
              PREFIX foaf: <http://xmlns.com/foaf/0.1/>
              PREFIX rdfa: <http://www.w3.org/ns/rdfa#>
              ASK WHERE { <http://example/> rdfa:usesVocabulary foaf: }
            )
            expect(parse(subject)).to pass_query(query, @debug)
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
                expect(parse(input, validate: false, base_uri: "http://example/")).to pass_query(query, @debug)
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
                expect(parse(input, base_uri: "http://example/")).to_not pass_query(query, @debug)
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
              expect(parse(input, base_uri: "http://example/")).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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
            "@property, and @value as float" => [
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
              expect(parse(input, base_uri: "http://example/")).to be_equivalent_graph(expected, trace: @debug, format: :ttl)
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
                expect(parse(input, :host_language => :xhtml1)).to be_equivalent_graph(expected1, :trace => @debug, :format => :ttl)
              end
            
              it "xhtml5" do
                expected5 = %(
                  @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                  @prefix xhv: <http://www.w3.org/1999/xhtml/vocab#> .
                  @prefix cc: <http://creativecommons.org/ns#> .
                ) + expected5
                expect(parse(input, :host_language => :xhtml5)).to be_equivalent_graph(expected5, :trace => @debug, :format => :ttl)
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
              expect(parse(input)).to be_equivalent_graph(expected, :trace => @debug, :format => :ttl)
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
            expect(parse(html, :validate => false)).to be_equivalent_graph(g_ttl, :trace => @debug, :format => :ttl)
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
          expect(parse(svg)).to pass_query(query, :trace => @debug)
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
            expect(parse(input)).to be_equivalent_graph(result, :base_uri => "http://example/", :trace => @debug)
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
        expect(parse(html)).to be_equivalent_graph(ttl, :trace => @debug)
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
          expect(parse(html, :rdfagraph => :processor)).to pass_query(query, :trace => @debug)
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
          expect(parse(html, :rdfagraph => :processor)).to pass_query(query, :trace => @debug)
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
            expect(parse(html, :rdfagraph => :processor)).to pass_query(query, :trace => @debug)
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
          expect(parse(html, :rdfagraph => :processor)).to pass_query(query, :trace => @debug)
        end
      end

      context :validation do
        it "needs some examples", :pending => true
      end
    end
  end

  describe "Base IRI resolution" do
    # From https://gist.github.com/RubenVerborgh/39f0e8d63e33e435371a
    let(:html) {%q{<html><body>
      <div xml:base="http://a/bb/ccc/d;p?q">
        <!-- RFC3986 normal examples -->
        <link about="urn:s001" property="urn:p" href="g:h"/>
        <link about="urn:s002" property="urn:p" href="g"/>
        <link about="urn:s003" property="urn:p" href="./g"/>
        <link about="urn:s004" property="urn:p" href="g/"/>
        <link about="urn:s005" property="urn:p" href="/g"/>
        <link about="urn:s006" property="urn:p" href="//g"/>
        <link about="urn:s007" property="urn:p" href="?y"/>
        <link about="urn:s008" property="urn:p" href="g?y"/>
        <link about="urn:s009" property="urn:p" href="#s"/>
        <link about="urn:s010" property="urn:p" href="g#s"/>
        <link about="urn:s011" property="urn:p" href="g?y#s"/>
        <link about="urn:s012" property="urn:p" href=";x"/>
        <link about="urn:s013" property="urn:p" href="g;x"/>
        <link about="urn:s014" property="urn:p" href="g;x?y#s"/>
        <link about="urn:s015" property="urn:p" href=""/>
        <link about="urn:s016" property="urn:p" href="."/>
        <link about="urn:s017" property="urn:p" href="./"/>
        <link about="urn:s018" property="urn:p" href=".."/>
        <link about="urn:s019" property="urn:p" href="../"/>
        <link about="urn:s020" property="urn:p" href="../g"/>
        <link about="urn:s021" property="urn:p" href="../.."/>
        <link about="urn:s022" property="urn:p" href="../../"/>
        <link about="urn:s023" property="urn:p" href="../../g"/>
      </div>

      <div xml:base="http://a/bb/ccc/d;p?q">
        <!-- RFC3986 abnormal examples -->
        <link about="urn:s024" property="urn:p" href="../../../g"/>
        <link about="urn:s025" property="urn:p" href="../../../../g"/>
        <link about="urn:s026" property="urn:p" href="/./g"/>
        <link about="urn:s027" property="urn:p" href="/../g"/>
        <link about="urn:s028" property="urn:p" href="g."/>
        <link about="urn:s029" property="urn:p" href=".g"/>
        <link about="urn:s030" property="urn:p" href="g.."/>
        <link about="urn:s031" property="urn:p" href="..g"/>
        <link about="urn:s032" property="urn:p" href="./../g"/>
        <link about="urn:s033" property="urn:p" href="./g/."/>
        <link about="urn:s034" property="urn:p" href="g/./h"/>
        <link about="urn:s035" property="urn:p" href="g/../h"/>
        <link about="urn:s036" property="urn:p" href="g;x=1/./y"/>
        <link about="urn:s037" property="urn:p" href="g;x=1/../y"/>
        <link about="urn:s038" property="urn:p" href="g?y/./x"/>
        <link about="urn:s039" property="urn:p" href="g?y/../x"/>
        <link about="urn:s040" property="urn:p" href="g#s/./x"/>
        <link about="urn:s041" property="urn:p" href="g#s/../x"/>
        <link about="urn:s042" property="urn:p" href="http:g"/>
      </div>

      <div xml:base="http://a/bb/ccc/d/">
        <!-- RFC3986 normal examples with trailing slash in base IRI -->
        <link about="urn:s043" property="urn:p" href="g:h"/>
        <link about="urn:s044" property="urn:p" href="g"/>
        <link about="urn:s045" property="urn:p" href="./g"/>
        <link about="urn:s046" property="urn:p" href="g/"/>
        <link about="urn:s047" property="urn:p" href="/g"/>
        <link about="urn:s048" property="urn:p" href="//g"/>
        <link about="urn:s049" property="urn:p" href="?y"/>
        <link about="urn:s050" property="urn:p" href="g?y"/>
        <link about="urn:s051" property="urn:p" href="#s"/>
        <link about="urn:s052" property="urn:p" href="g#s"/>
        <link about="urn:s053" property="urn:p" href="g?y#s"/>
        <link about="urn:s054" property="urn:p" href=";x"/>
        <link about="urn:s055" property="urn:p" href="g;x"/>
        <link about="urn:s056" property="urn:p" href="g;x?y#s"/>
        <link about="urn:s057" property="urn:p" href=""/>
        <link about="urn:s058" property="urn:p" href="."/>
        <link about="urn:s059" property="urn:p" href="./"/>
        <link about="urn:s060" property="urn:p" href=".."/>
        <link about="urn:s061" property="urn:p" href="../"/>
        <link about="urn:s062" property="urn:p" href="../g"/>
        <link about="urn:s063" property="urn:p" href="../.."/>
        <link about="urn:s064" property="urn:p" href="../../"/>
        <link about="urn:s065" property="urn:p" href="../../g"/>
      </div>

      <div xml:base="http://a/bb/ccc/d/">
        <!-- RFC3986 abnormal examples with trailing slash in base IRI -->
        <link about="urn:s066" property="urn:p" href="../../../g"/>
        <link about="urn:s067" property="urn:p" href="../../../../g"/>
        <link about="urn:s068" property="urn:p" href="/./g"/>
        <link about="urn:s069" property="urn:p" href="/../g"/>
        <link about="urn:s070" property="urn:p" href="g."/>
        <link about="urn:s071" property="urn:p" href=".g"/>
        <link about="urn:s072" property="urn:p" href="g.."/>
        <link about="urn:s073" property="urn:p" href="..g"/>
        <link about="urn:s074" property="urn:p" href="./../g"/>
        <link about="urn:s075" property="urn:p" href="./g/."/>
        <link about="urn:s076" property="urn:p" href="g/./h"/>
        <link about="urn:s077" property="urn:p" href="g/../h"/>
        <link about="urn:s078" property="urn:p" href="g;x=1/./y"/>
        <link about="urn:s079" property="urn:p" href="g;x=1/../y"/>
        <link about="urn:s080" property="urn:p" href="g?y/./x"/>
        <link about="urn:s081" property="urn:p" href="g?y/../x"/>
        <link about="urn:s082" property="urn:p" href="g#s/./x"/>
        <link about="urn:s083" property="urn:p" href="g#s/../x"/>
        <link about="urn:s084" property="urn:p" href="http:g"/>
      </div>

      <div xml:base="http://a/bb/ccc/./d;p?q">
        <!-- RFC3986 normal examples0 with ./ in the base IRI -->
        <link about="urn:s085" property="urn:p" href="g:h"/>
        <link about="urn:s086" property="urn:p" href="g"/>
        <link about="urn:s087" property="urn:p" href="./g"/>
        <link about="urn:s088" property="urn:p" href="g/"/>
        <link about="urn:s089" property="urn:p" href="/g"/>
        <link about="urn:s090" property="urn:p" href="//g"/>
        <link about="urn:s091" property="urn:p" href="?y"/>
        <link about="urn:s092" property="urn:p" href="g?y"/>
        <link about="urn:s093" property="urn:p" href="#s"/>
        <link about="urn:s094" property="urn:p" href="g#s"/>
        <link about="urn:s095" property="urn:p" href="g?y#s"/>
        <link about="urn:s096" property="urn:p" href=";x"/>
        <link about="urn:s097" property="urn:p" href="g;x"/>
        <link about="urn:s098" property="urn:p" href="g;x?y#s"/>
        <link about="urn:s099" property="urn:p" href=""/>
        <link about="urn:s100" property="urn:p" href="."/>
        <link about="urn:s101" property="urn:p" href="./"/>
        <link about="urn:s102" property="urn:p" href=".."/>
        <link about="urn:s103" property="urn:p" href="../"/>
        <link about="urn:s104" property="urn:p" href="../g"/>
        <link about="urn:s105" property="urn:p" href="../.."/>
        <link about="urn:s106" property="urn:p" href="../../"/>
        <link about="urn:s107" property="urn:p" href="../../g"/>
      </div>

      <div xml:base="http://a/bb/ccc/./d;p?q">
        <!-- RFC3986 abnormal examples with ./ in the base IRI -->
        <link about="urn:s108" property="urn:p" href="../../../g"/>
        <link about="urn:s109" property="urn:p" href="../../../../g"/>
        <link about="urn:s110" property="urn:p" href="/./g"/>
        <link about="urn:s111" property="urn:p" href="/../g"/>
        <link about="urn:s112" property="urn:p" href="g."/>
        <link about="urn:s113" property="urn:p" href=".g"/>
        <link about="urn:s114" property="urn:p" href="g.."/>
        <link about="urn:s115" property="urn:p" href="..g"/>
        <link about="urn:s116" property="urn:p" href="./../g"/>
        <link about="urn:s117" property="urn:p" href="./g/."/>
        <link about="urn:s118" property="urn:p" href="g/./h"/>
        <link about="urn:s119" property="urn:p" href="g/../h"/>
        <link about="urn:s120" property="urn:p" href="g;x=1/./y"/>
        <link about="urn:s121" property="urn:p" href="g;x=1/../y"/>
        <link about="urn:s122" property="urn:p" href="g?y/./x"/>
        <link about="urn:s123" property="urn:p" href="g?y/../x"/>
        <link about="urn:s124" property="urn:p" href="g#s/./x"/>
        <link about="urn:s125" property="urn:p" href="g#s/../x"/>
        <link about="urn:s126" property="urn:p" href="http:g"/>
      </div>

      <div xml:base="http://a/bb/ccc/../d;p?q">
        <!-- RFC3986 normal examples with ../ in the base IRI -->
        <link about="urn:s127" property="urn:p" href="g:h"/>
        <link about="urn:s128" property="urn:p" href="g"/>
        <link about="urn:s129" property="urn:p" href="./g"/>
        <link about="urn:s130" property="urn:p" href="g/"/>
        <link about="urn:s131" property="urn:p" href="/g"/>
        <link about="urn:s132" property="urn:p" href="//g"/>
        <link about="urn:s133" property="urn:p" href="?y"/>
        <link about="urn:s134" property="urn:p" href="g?y"/>
        <link about="urn:s135" property="urn:p" href="#s"/>
        <link about="urn:s136" property="urn:p" href="g#s"/>
        <link about="urn:s137" property="urn:p" href="g?y#s"/>
        <link about="urn:s138" property="urn:p" href=";x"/>
        <link about="urn:s139" property="urn:p" href="g;x"/>
        <link about="urn:s140" property="urn:p" href="g;x?y#s"/>
        <link about="urn:s141" property="urn:p" href=""/>
        <link about="urn:s142" property="urn:p" href="."/>
        <link about="urn:s143" property="urn:p" href="./"/>
        <link about="urn:s144" property="urn:p" href=".."/>
        <link about="urn:s145" property="urn:p" href="../"/>
        <link about="urn:s146" property="urn:p" href="../g"/>
        <link about="urn:s147" property="urn:p" href="../.."/>
        <link about="urn:s148" property="urn:p" href="../../"/>
        <link about="urn:s149" property="urn:p" href="../../g"/>
      </div>

      <div xml:base="http://a/bb/ccc/../d;p?q">
        <!-- RFC3986 abnormal examples with ../ in the base IRI -->
        <link about="urn:s150" property="urn:p" href="../../../g"/>
        <link about="urn:s151" property="urn:p" href="../../../../g"/>
        <link about="urn:s152" property="urn:p" href="/./g"/>
        <link about="urn:s153" property="urn:p" href="/../g"/>
        <link about="urn:s154" property="urn:p" href="g."/>
        <link about="urn:s155" property="urn:p" href=".g"/>
        <link about="urn:s156" property="urn:p" href="g.."/>
        <link about="urn:s157" property="urn:p" href="..g"/>
        <link about="urn:s158" property="urn:p" href="./../g"/>
        <link about="urn:s159" property="urn:p" href="./g/."/>
        <link about="urn:s160" property="urn:p" href="g/./h"/>
        <link about="urn:s161" property="urn:p" href="g/../h"/>
        <link about="urn:s162" property="urn:p" href="g;x=1/./y"/>
        <link about="urn:s163" property="urn:p" href="g;x=1/../y"/>
        <link about="urn:s164" property="urn:p" href="g?y/./x"/>
        <link about="urn:s165" property="urn:p" href="g?y/../x"/>
        <link about="urn:s166" property="urn:p" href="g#s/./x"/>
        <link about="urn:s167" property="urn:p" href="g#s/../x"/>
        <link about="urn:s168" property="urn:p" href="http:g"/>
      </div>

      <div xml:base="http://a/bb/ccc/.">
        <!-- RFC3986 normal examples with trailing ./ in the base IRI -->
        <link about="urn:s169" property="urn:p" href="g:h"/>
        <link about="urn:s170" property="urn:p" href="g"/>
        <link about="urn:s171" property="urn:p" href="./g"/>
        <link about="urn:s172" property="urn:p" href="g/"/>
        <link about="urn:s173" property="urn:p" href="/g"/>
        <link about="urn:s174" property="urn:p" href="//g"/>
        <link about="urn:s175" property="urn:p" href="?y"/>
        <link about="urn:s176" property="urn:p" href="g?y"/>
        <link about="urn:s177" property="urn:p" href="#s"/>
        <link about="urn:s178" property="urn:p" href="g#s"/>
        <link about="urn:s179" property="urn:p" href="g?y#s"/>
        <link about="urn:s180" property="urn:p" href=";x"/>
        <link about="urn:s181" property="urn:p" href="g;x"/>
        <link about="urn:s182" property="urn:p" href="g;x?y#s"/>
        <link about="urn:s183" property="urn:p" href=""/>
        <link about="urn:s184" property="urn:p" href="."/>
        <link about="urn:s185" property="urn:p" href="./"/>
        <link about="urn:s186" property="urn:p" href=".."/>
        <link about="urn:s187" property="urn:p" href="../"/>
        <link about="urn:s188" property="urn:p" href="../g"/>
        <link about="urn:s189" property="urn:p" href="../.."/>
        <link about="urn:s190" property="urn:p" href="../../"/>
        <link about="urn:s191" property="urn:p" href="../../g"/>
      </div>

      <div xml:base="http://a/bb/ccc/.">
        <!-- RFC3986 abnormal examples with trailing ./ in the base IRI -->
        <link about="urn:s192" property="urn:p" href="../../../g"/>
        <link about="urn:s193" property="urn:p" href="../../../../g"/>
        <link about="urn:s194" property="urn:p" href="/./g"/>
        <link about="urn:s195" property="urn:p" href="/../g"/>
        <link about="urn:s196" property="urn:p" href="g."/>
        <link about="urn:s197" property="urn:p" href=".g"/>
        <link about="urn:s198" property="urn:p" href="g.."/>
        <link about="urn:s199" property="urn:p" href="..g"/>
        <link about="urn:s200" property="urn:p" href="./../g"/>
        <link about="urn:s201" property="urn:p" href="./g/."/>
        <link about="urn:s202" property="urn:p" href="g/./h"/>
        <link about="urn:s203" property="urn:p" href="g/../h"/>
        <link about="urn:s204" property="urn:p" href="g;x=1/./y"/>
        <link about="urn:s205" property="urn:p" href="g;x=1/../y"/>
        <link about="urn:s206" property="urn:p" href="g?y/./x"/>
        <link about="urn:s207" property="urn:p" href="g?y/../x"/>
        <link about="urn:s208" property="urn:p" href="g#s/./x"/>
        <link about="urn:s209" property="urn:p" href="g#s/../x"/>
        <link about="urn:s210" property="urn:p" href="http:g"/>
      </div>

      <div xml:base="http://a/bb/ccc/..">
        <!-- RFC3986 normal examples with trailing ../ in the base IRI -->
        <link about="urn:s211" property="urn:p" href="g:h"/>
        <link about="urn:s212" property="urn:p" href="g"/>
        <link about="urn:s213" property="urn:p" href="./g"/>
        <link about="urn:s214" property="urn:p" href="g/"/>
        <link about="urn:s215" property="urn:p" href="/g"/>
        <link about="urn:s216" property="urn:p" href="//g"/>
        <link about="urn:s217" property="urn:p" href="?y"/>
        <link about="urn:s218" property="urn:p" href="g?y"/>
        <link about="urn:s219" property="urn:p" href="#s"/>
        <link about="urn:s220" property="urn:p" href="g#s"/>
        <link about="urn:s221" property="urn:p" href="g?y#s"/>
        <link about="urn:s222" property="urn:p" href=";x"/>
        <link about="urn:s223" property="urn:p" href="g;x"/>
        <link about="urn:s224" property="urn:p" href="g;x?y#s"/>
        <link about="urn:s225" property="urn:p" href=""/>
        <link about="urn:s226" property="urn:p" href="."/>
        <link about="urn:s227" property="urn:p" href="./"/>
        <link about="urn:s228" property="urn:p" href=".."/>
        <link about="urn:s229" property="urn:p" href="../"/>
        <link about="urn:s230" property="urn:p" href="../g"/>
        <link about="urn:s231" property="urn:p" href="../.."/>
        <link about="urn:s232" property="urn:p" href="../../"/>
        <link about="urn:s233" property="urn:p" href="../../g"/>
        <link about="urn:s210" property="urn:p" href="http:g"/>
      </div>

      <div xml:base="http://a/bb/ccc/..">
        <!-- RFC3986 abnormal examples with trailing ../ in the base IRI -->
        <link about="urn:s234" property="urn:p" href="../../../g"/>
        <link about="urn:s235" property="urn:p" href="../../../../g"/>
        <link about="urn:s236" property="urn:p" href="/./g"/>
        <link about="urn:s237" property="urn:p" href="/../g"/>
        <link about="urn:s238" property="urn:p" href="g."/>
        <link about="urn:s239" property="urn:p" href=".g"/>
        <link about="urn:s240" property="urn:p" href="g.."/>
        <link about="urn:s241" property="urn:p" href="..g"/>
        <link about="urn:s242" property="urn:p" href="./../g"/>
        <link about="urn:s243" property="urn:p" href="./g/."/>
        <link about="urn:s244" property="urn:p" href="g/./h"/>
        <link about="urn:s245" property="urn:p" href="g/../h"/>
        <link about="urn:s246" property="urn:p" href="g;x=1/./y"/>
        <link about="urn:s247" property="urn:p" href="g;x=1/../y"/>
        <link about="urn:s248" property="urn:p" href="g?y/./x"/>
        <link about="urn:s249" property="urn:p" href="g?y/../x"/>
        <link about="urn:s250" property="urn:p" href="g#s/./x"/>
        <link about="urn:s251" property="urn:p" href="g#s/../x"/>
        <link about="urn:s252" property="urn:p" href="http:g"/>
      </div>

      <!-- additional cases -->
      <div xml:base="http://abc/def/ghi">
        <link about="urn:s253" property="urn:p" href="."/>
        <link about="urn:s254" property="urn:p" href=".?a=b"/>
        <link about="urn:s255" property="urn:p" href=".#a=b"/>
        <link about="urn:s256" property="urn:p" href=".."/>
        <link about="urn:s257" property="urn:p" href="..?a=b"/>
        <link about="urn:s258" property="urn:p" href="..#a=b"/>
      </div>
      <div xml:base="http://ab//de//ghi">
        <link about="urn:s259" property="urn:p" href="xyz"/>
        <link about="urn:s260" property="urn:p" href="./xyz"/>
        <link about="urn:s261" property="urn:p" href="../xyz"/>
      </div>
      <div xml:base="http://abc/d:f/ghi">
        <link about="urn:s262" property="urn:p" href="xyz"/>
        <link about="urn:s263" property="urn:p" href="./xyz"/>
        <link about="urn:s264" property="urn:p" href="../xyz"/>
      </div>
    </body></html>}}
    let(:nt) {%q{
      # RFC3986 normal examples

      <urn:s001> <urn:p> <g:h>.
      <urn:s002> <urn:p> <http://a/bb/ccc/g>.
      <urn:s003> <urn:p> <http://a/bb/ccc/g>.
      <urn:s004> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s005> <urn:p> <http://a/g>.
      <urn:s006> <urn:p> <http://g>.
      <urn:s007> <urn:p> <http://a/bb/ccc/d;p?y>.
      <urn:s008> <urn:p> <http://a/bb/ccc/g?y>.
      <urn:s009> <urn:p> <http://a/bb/ccc/d;p?q#s>.
      <urn:s010> <urn:p> <http://a/bb/ccc/g#s>.
      <urn:s011> <urn:p> <http://a/bb/ccc/g?y#s>.
      <urn:s012> <urn:p> <http://a/bb/ccc/;x>.
      <urn:s013> <urn:p> <http://a/bb/ccc/g;x>.
      <urn:s014> <urn:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:s015> <urn:p> <http://a/bb/ccc/d;p?q>.
      <urn:s016> <urn:p> <http://a/bb/ccc/>.
      <urn:s017> <urn:p> <http://a/bb/ccc/>.
      <urn:s018> <urn:p> <http://a/bb/>.
      <urn:s019> <urn:p> <http://a/bb/>.
      <urn:s020> <urn:p> <http://a/bb/g>.
      <urn:s021> <urn:p> <http://a/>.
      <urn:s022> <urn:p> <http://a/>.
      <urn:s023> <urn:p> <http://a/g>.

      # RFC3986 abnormal examples

      <urn:s024> <urn:p> <http://a/g>.
      <urn:s025> <urn:p> <http://a/g>.
      <urn:s026> <urn:p> <http://a/g>.
      <urn:s027> <urn:p> <http://a/g>.
      <urn:s028> <urn:p> <http://a/bb/ccc/g.>.
      <urn:s029> <urn:p> <http://a/bb/ccc/.g>.
      <urn:s030> <urn:p> <http://a/bb/ccc/g..>.
      <urn:s031> <urn:p> <http://a/bb/ccc/..g>.
      <urn:s032> <urn:p> <http://a/bb/g>.
      <urn:s033> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s034> <urn:p> <http://a/bb/ccc/g/h>.
      <urn:s035> <urn:p> <http://a/bb/ccc/h>.
      <urn:s036> <urn:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:s037> <urn:p> <http://a/bb/ccc/y>.
      <urn:s038> <urn:p> <http://a/bb/ccc/g?y/./x>.
      <urn:s039> <urn:p> <http://a/bb/ccc/g?y/../x>.
      <urn:s040> <urn:p> <http://a/bb/ccc/g#s/./x>.
      <urn:s041> <urn:p> <http://a/bb/ccc/g#s/../x>.
      <urn:s042> <urn:p> <http:g>.

      # RFC3986 normal examples with trailing slash in base IRI

      <urn:s043> <urn:p> <g:h>.
      <urn:s044> <urn:p> <http://a/bb/ccc/d/g>.
      <urn:s045> <urn:p> <http://a/bb/ccc/d/g>.
      <urn:s046> <urn:p> <http://a/bb/ccc/d/g/>.
      <urn:s047> <urn:p> <http://a/g>.
      <urn:s048> <urn:p> <http://g>.
      <urn:s049> <urn:p> <http://a/bb/ccc/d/?y>.
      <urn:s050> <urn:p> <http://a/bb/ccc/d/g?y>.
      <urn:s051> <urn:p> <http://a/bb/ccc/d/#s>.
      <urn:s052> <urn:p> <http://a/bb/ccc/d/g#s>.
      <urn:s053> <urn:p> <http://a/bb/ccc/d/g?y#s>.
      <urn:s054> <urn:p> <http://a/bb/ccc/d/;x>.
      <urn:s055> <urn:p> <http://a/bb/ccc/d/g;x>.
      <urn:s056> <urn:p> <http://a/bb/ccc/d/g;x?y#s>.
      <urn:s057> <urn:p> <http://a/bb/ccc/d/>.
      <urn:s058> <urn:p> <http://a/bb/ccc/d/>.
      <urn:s059> <urn:p> <http://a/bb/ccc/d/>.
      <urn:s060> <urn:p> <http://a/bb/ccc/>.
      <urn:s061> <urn:p> <http://a/bb/ccc/>.
      <urn:s062> <urn:p> <http://a/bb/ccc/g>.
      <urn:s063> <urn:p> <http://a/bb/>.
      <urn:s064> <urn:p> <http://a/bb/>.
      <urn:s065> <urn:p> <http://a/bb/g>.

      # RFC3986 abnormal examples with trailing slash in base IRI

      <urn:s066> <urn:p> <http://a/g>.
      <urn:s067> <urn:p> <http://a/g>.
      <urn:s068> <urn:p> <http://a/g>.
      <urn:s069> <urn:p> <http://a/g>.
      <urn:s070> <urn:p> <http://a/bb/ccc/d/g.>.
      <urn:s071> <urn:p> <http://a/bb/ccc/d/.g>.
      <urn:s072> <urn:p> <http://a/bb/ccc/d/g..>.
      <urn:s073> <urn:p> <http://a/bb/ccc/d/..g>.
      <urn:s074> <urn:p> <http://a/bb/ccc/g>.
      <urn:s075> <urn:p> <http://a/bb/ccc/d/g/>.
      <urn:s076> <urn:p> <http://a/bb/ccc/d/g/h>.
      <urn:s077> <urn:p> <http://a/bb/ccc/d/h>.
      <urn:s078> <urn:p> <http://a/bb/ccc/d/g;x=1/y>.
      <urn:s079> <urn:p> <http://a/bb/ccc/d/y>.
      <urn:s080> <urn:p> <http://a/bb/ccc/d/g?y/./x>.
      <urn:s081> <urn:p> <http://a/bb/ccc/d/g?y/../x>.
      <urn:s082> <urn:p> <http://a/bb/ccc/d/g#s/./x>.
      <urn:s083> <urn:p> <http://a/bb/ccc/d/g#s/../x>.
      <urn:s084> <urn:p> <http:g>.

      # RFC3986 normal examples with ./ in the base IRI

      <urn:s085> <urn:p> <g:h>.
      <urn:s086> <urn:p> <http://a/bb/ccc/g>.
      <urn:s087> <urn:p> <http://a/bb/ccc/g>.
      <urn:s088> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s089> <urn:p> <http://a/g>.
      <urn:s090> <urn:p> <http://g>.
      <urn:s091> <urn:p> <http://a/bb/ccc/./d;p?y>.
      <urn:s092> <urn:p> <http://a/bb/ccc/g?y>.
      <urn:s093> <urn:p> <http://a/bb/ccc/./d;p?q#s>.
      <urn:s094> <urn:p> <http://a/bb/ccc/g#s>.
      <urn:s095> <urn:p> <http://a/bb/ccc/g?y#s>.
      <urn:s096> <urn:p> <http://a/bb/ccc/;x>.
      <urn:s097> <urn:p> <http://a/bb/ccc/g;x>.
      <urn:s098> <urn:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:s099> <urn:p> <http://a/bb/ccc/./d;p?q>.
      <urn:s100> <urn:p> <http://a/bb/ccc/>.
      <urn:s101> <urn:p> <http://a/bb/ccc/>.
      <urn:s102> <urn:p> <http://a/bb/>.
      <urn:s103> <urn:p> <http://a/bb/>.
      <urn:s104> <urn:p> <http://a/bb/g>.
      <urn:s105> <urn:p> <http://a/>.
      <urn:s106> <urn:p> <http://a/>.
      <urn:s107> <urn:p> <http://a/g>.

      # RFC3986 abnormal examples with ./ in the base IRI

      <urn:s108> <urn:p> <http://a/g>.
      <urn:s109> <urn:p> <http://a/g>.
      <urn:s110> <urn:p> <http://a/g>.
      <urn:s111> <urn:p> <http://a/g>.
      <urn:s112> <urn:p> <http://a/bb/ccc/g.>.
      <urn:s113> <urn:p> <http://a/bb/ccc/.g>.
      <urn:s114> <urn:p> <http://a/bb/ccc/g..>.
      <urn:s115> <urn:p> <http://a/bb/ccc/..g>.
      <urn:s116> <urn:p> <http://a/bb/g>.
      <urn:s117> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s118> <urn:p> <http://a/bb/ccc/g/h>.
      <urn:s119> <urn:p> <http://a/bb/ccc/h>.
      <urn:s120> <urn:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:s121> <urn:p> <http://a/bb/ccc/y>.
      <urn:s122> <urn:p> <http://a/bb/ccc/g?y/./x>.
      <urn:s123> <urn:p> <http://a/bb/ccc/g?y/../x>.
      <urn:s124> <urn:p> <http://a/bb/ccc/g#s/./x>.
      <urn:s125> <urn:p> <http://a/bb/ccc/g#s/../x>.
      <urn:s126> <urn:p> <http:g>.

      # RFC3986 normal examples with ../ in the base IRI

      <urn:s127> <urn:p> <g:h>.
      <urn:s128> <urn:p> <http://a/bb/g>.
      <urn:s129> <urn:p> <http://a/bb/g>.
      <urn:s130> <urn:p> <http://a/bb/g/>.
      <urn:s131> <urn:p> <http://a/g>.
      <urn:s132> <urn:p> <http://g>.
      <urn:s133> <urn:p> <http://a/bb/ccc/../d;p?y>.
      <urn:s134> <urn:p> <http://a/bb/g?y>.
      <urn:s135> <urn:p> <http://a/bb/ccc/../d;p?q#s>.
      <urn:s136> <urn:p> <http://a/bb/g#s>.
      <urn:s137> <urn:p> <http://a/bb/g?y#s>.
      <urn:s138> <urn:p> <http://a/bb/;x>.
      <urn:s139> <urn:p> <http://a/bb/g;x>.
      <urn:s140> <urn:p> <http://a/bb/g;x?y#s>.
      <urn:s141> <urn:p> <http://a/bb/ccc/../d;p?q>.
      <urn:s142> <urn:p> <http://a/bb/>.
      <urn:s143> <urn:p> <http://a/bb/>.
      <urn:s144> <urn:p> <http://a/>.
      <urn:s145> <urn:p> <http://a/>.
      <urn:s146> <urn:p> <http://a/g>.
      <urn:s147> <urn:p> <http://a/>.
      <urn:s148> <urn:p> <http://a/>.
      <urn:s149> <urn:p> <http://a/g>.

      # RFC3986 abnormal examples with ../ in the base IRI

      <urn:s150> <urn:p> <http://a/g>.
      <urn:s151> <urn:p> <http://a/g>.
      <urn:s152> <urn:p> <http://a/g>.
      <urn:s153> <urn:p> <http://a/g>.
      <urn:s154> <urn:p> <http://a/bb/g.>.
      <urn:s155> <urn:p> <http://a/bb/.g>.
      <urn:s156> <urn:p> <http://a/bb/g..>.
      <urn:s157> <urn:p> <http://a/bb/..g>.
      <urn:s158> <urn:p> <http://a/g>.
      <urn:s159> <urn:p> <http://a/bb/g/>.
      <urn:s160> <urn:p> <http://a/bb/g/h>.
      <urn:s161> <urn:p> <http://a/bb/h>.
      <urn:s162> <urn:p> <http://a/bb/g;x=1/y>.
      <urn:s163> <urn:p> <http://a/bb/y>.
      <urn:s164> <urn:p> <http://a/bb/g?y/./x>.
      <urn:s165> <urn:p> <http://a/bb/g?y/../x>.
      <urn:s166> <urn:p> <http://a/bb/g#s/./x>.
      <urn:s167> <urn:p> <http://a/bb/g#s/../x>.
      <urn:s168> <urn:p> <http:g>.

      # RFC3986 normal examples with trailing ./ in the base IRI

      <urn:s169> <urn:p> <g:h>.
      <urn:s170> <urn:p> <http://a/bb/ccc/g>.
      <urn:s171> <urn:p> <http://a/bb/ccc/g>.
      <urn:s172> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s173> <urn:p> <http://a/g>.
      <urn:s174> <urn:p> <http://g>.
      <urn:s175> <urn:p> <http://a/bb/ccc/.?y>.
      <urn:s176> <urn:p> <http://a/bb/ccc/g?y>.
      <urn:s177> <urn:p> <http://a/bb/ccc/.#s>.
      <urn:s178> <urn:p> <http://a/bb/ccc/g#s>.
      <urn:s179> <urn:p> <http://a/bb/ccc/g?y#s>.
      <urn:s180> <urn:p> <http://a/bb/ccc/;x>.
      <urn:s181> <urn:p> <http://a/bb/ccc/g;x>.
      <urn:s182> <urn:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:s183> <urn:p> <http://a/bb/ccc/.>.
      <urn:s184> <urn:p> <http://a/bb/ccc/>.
      <urn:s185> <urn:p> <http://a/bb/ccc/>.
      <urn:s186> <urn:p> <http://a/bb/>.
      <urn:s187> <urn:p> <http://a/bb/>.
      <urn:s188> <urn:p> <http://a/bb/g>.
      <urn:s189> <urn:p> <http://a/>.
      <urn:s190> <urn:p> <http://a/>.
      <urn:s191> <urn:p> <http://a/g>.

      # RFC3986 abnormal examples with trailing ./ in the base IRI

      <urn:s192> <urn:p> <http://a/g>.
      <urn:s193> <urn:p> <http://a/g>.
      <urn:s194> <urn:p> <http://a/g>.
      <urn:s195> <urn:p> <http://a/g>.
      <urn:s196> <urn:p> <http://a/bb/ccc/g.>.
      <urn:s197> <urn:p> <http://a/bb/ccc/.g>.
      <urn:s198> <urn:p> <http://a/bb/ccc/g..>.
      <urn:s199> <urn:p> <http://a/bb/ccc/..g>.
      <urn:s200> <urn:p> <http://a/bb/g>.
      <urn:s201> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s202> <urn:p> <http://a/bb/ccc/g/h>.
      <urn:s203> <urn:p> <http://a/bb/ccc/h>.
      <urn:s204> <urn:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:s205> <urn:p> <http://a/bb/ccc/y>.
      <urn:s206> <urn:p> <http://a/bb/ccc/g?y/./x>.
      <urn:s207> <urn:p> <http://a/bb/ccc/g?y/../x>.
      <urn:s208> <urn:p> <http://a/bb/ccc/g#s/./x>.
      <urn:s209> <urn:p> <http://a/bb/ccc/g#s/../x>.
      <urn:s210> <urn:p> <http:g>.

      # RFC3986 normal examples with trailing ../ in the base IRI

      <urn:s211> <urn:p> <g:h>.
      <urn:s212> <urn:p> <http://a/bb/ccc/g>.
      <urn:s213> <urn:p> <http://a/bb/ccc/g>.
      <urn:s214> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s215> <urn:p> <http://a/g>.
      <urn:s216> <urn:p> <http://g>.
      <urn:s217> <urn:p> <http://a/bb/ccc/..?y>.
      <urn:s218> <urn:p> <http://a/bb/ccc/g?y>.
      <urn:s219> <urn:p> <http://a/bb/ccc/..#s>.
      <urn:s220> <urn:p> <http://a/bb/ccc/g#s>.
      <urn:s221> <urn:p> <http://a/bb/ccc/g?y#s>.
      <urn:s222> <urn:p> <http://a/bb/ccc/;x>.
      <urn:s223> <urn:p> <http://a/bb/ccc/g;x>.
      <urn:s224> <urn:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:s225> <urn:p> <http://a/bb/ccc/..>.
      <urn:s226> <urn:p> <http://a/bb/ccc/>.
      <urn:s227> <urn:p> <http://a/bb/ccc/>.
      <urn:s228> <urn:p> <http://a/bb/>.
      <urn:s229> <urn:p> <http://a/bb/>.
      <urn:s230> <urn:p> <http://a/bb/g>.
      <urn:s231> <urn:p> <http://a/>.
      <urn:s232> <urn:p> <http://a/>.
      <urn:s233> <urn:p> <http://a/g>.

      # RFC3986 abnormal examples with trailing ../ in the base IRI

      <urn:s234> <urn:p> <http://a/g>.
      <urn:s235> <urn:p> <http://a/g>.
      <urn:s236> <urn:p> <http://a/g>.
      <urn:s237> <urn:p> <http://a/g>.
      <urn:s238> <urn:p> <http://a/bb/ccc/g.>.
      <urn:s239> <urn:p> <http://a/bb/ccc/.g>.
      <urn:s240> <urn:p> <http://a/bb/ccc/g..>.
      <urn:s241> <urn:p> <http://a/bb/ccc/..g>.
      <urn:s242> <urn:p> <http://a/bb/g>.
      <urn:s243> <urn:p> <http://a/bb/ccc/g/>.
      <urn:s244> <urn:p> <http://a/bb/ccc/g/h>.
      <urn:s245> <urn:p> <http://a/bb/ccc/h>.
      <urn:s246> <urn:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:s247> <urn:p> <http://a/bb/ccc/y>.
      <urn:s248> <urn:p> <http://a/bb/ccc/g?y/./x>.
      <urn:s249> <urn:p> <http://a/bb/ccc/g?y/../x>.
      <urn:s250> <urn:p> <http://a/bb/ccc/g#s/./x>.
      <urn:s251> <urn:p> <http://a/bb/ccc/g#s/../x>.
      <urn:s252> <urn:p> <http:g>.

      # additional cases

      <urn:s253> <urn:p> <http://abc/def/>.
      <urn:s254> <urn:p> <http://abc/def/?a=b>.
      <urn:s255> <urn:p> <http://abc/def/#a=b>.
      <urn:s256> <urn:p> <http://abc/>.
      <urn:s257> <urn:p> <http://abc/?a=b>.
      <urn:s258> <urn:p> <http://abc/#a=b>.

      <urn:s259> <urn:p> <http://ab//de//xyz>.
      <urn:s260> <urn:p> <http://ab//de//xyz>.
      <urn:s261> <urn:p> <http://ab//de/xyz>.

      <urn:s262> <urn:p> <http://abc/d:f/xyz>.
      <urn:s263> <urn:p> <http://abc/d:f/xyz>.
      <urn:s264> <urn:p> <http://abc/xyz>.
    }}
    it "produces equivalent triples" do
      nt_str = RDF::NTriples::Reader.new(nt).dump(:ntriples)
      html_str = RDF::RDFa::Reader.new(html, host_language: :xhtml5).dump(:ntriples)
      expect(html_str).to eql(nt_str)
    end
  end

  def parse(input, options = {})
    @debug = options[:debug] || []
    graph = RDF::Graph.new
    RDF::RDFa::Reader.new(input, options.merge(debug: @debug, library: @library)).each do |statement|
      graph << statement rescue fail "SPEC: #{$!}"
    end
    graph
  end

end
