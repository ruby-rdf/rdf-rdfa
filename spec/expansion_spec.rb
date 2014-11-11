$:.unshift "."
require 'spec_helper'

class EXP < RDF::Vocabulary("http://example.org/vocab#")
  property :name, subPropertyOf: "foaf:name", type: "rdf:Property"
  property :namee, "owl:equivalentProperty" => "foaf:name", type: "rdf:Property"
  term     :Person, subClassOf: "foaf:Person", type: "rdfs:Class"
  term     :Persone, "owl:equivalentClass" => "foaf:Person", type: "rdfs:Class"
end

# Class for abstract testing of module
class ExpansionTester
  include RDF::RDFa::Expansion
  include RDF::Enumerable

  attr_reader :about, :information, :repo, :inputDocument, :outputDocument, :options, :repo
  attr_accessor :format

  def initialize(name)
    @about = @information = name
    @repo = RDF::Repository.new

    super()
  end

  def graph
    g = RDF::Graph.new
    @repo.each {|st| g << st if st.context.nil? }
    g
  end

  def each_statement(&block); @repo.each_statement(&block); end

  def expectedResults; RDF::Literal::Boolean.new(true); end

  def add_debug(node, message = "")
    message = message + yield if block_given?
    @trace ||= []
    @trace << "#{node}: #{message}"
    #STDERR.puts "#{node}: #{message}"
  end
  
  def add_warning(node, message, process_class = RDF::RDFA.Warning)
    message = message + yield if block_given?
    @trace ||= []
    @trace << "#{node}(#{process_class}): #{message}"
    #STDERR.puts "#{node}: #{message}"
  end
  
  def trace; Array(@trace).join("\n"); end
  
  def load(elements)
    @options = {}
    result = nil
    elements.each do |context, value|
      case context
      when :default
        @inputDocument = value
        @repo << parse(value)
      when :query
        @outputDocument = value
        result = %(
          PREFIX dc:  <#{RDF::DC.to_uri}>
          PREFIX foaf:<#{RDF::FOAF.to_uri}>
          PREFIX owl: <#{RDF::OWL.to_uri}>
          PREFIX rdf: <#{RDF.to_uri}>
          PREFIX rdfa:<#{RDF::RDFA.to_uri}>
          PREFIX rdfs:<#{RDF::RDFS.to_uri}>
          PREFIX xsd: <#{RDF::XSD.to_uri}>
          PREFIX exp: <#{EXP.to_uri}>
          PREFIX :    <#{EXP.to_uri}>
          ASK WHERE {#{value}}
        )
      end
    end
    
    result
  end
  
  def parse(ttl)
    RDF::Graph.new << RDF::Turtle::Reader.new(ttl, prefixes: {
      dc:   RDF::DC.to_uri,
      foaf: RDF::FOAF.to_uri,
      owl:  RDF::OWL.to_uri,
      rdf:  RDF.to_uri,
      rdfa: RDF::RDFA.to_uri,
      rdfs: RDF::RDFS.to_uri,
      xsd:  RDF::XSD.to_uri,
      exp:  EXP.to_uri,
      nil   => EXP.to_uri,
    })
  end
end

describe RDF::RDFa::Expansion do

  describe :entailment do
    {
      "empty"   => {
        default: %q(),
        query: %q()
      },
      "simple"   => {
        default: %q(:a a rdfs:Class .),
        query: %q(
          :a a rdfs:Class, rdfs:Resource .
        )
      },
      "prp-spo1"   => {
        default: %q(<#me> :name "Gregg Kellogg" .),
        query: %q(
          <#me> :name "Gregg Kellogg"; foaf:name "Gregg Kellogg" .
        )
      },
      "prp-eqp1"   => {
        default: %q(<#me> :namee "Gregg Kellogg" .),
        query: %q(
          <#me> :namee "Gregg Kellogg"; foaf:name "Gregg Kellogg" .
        )
      },
      "prp-eqp2"   => {
        default: %q(<#me> foaf:name "Gregg Kellogg" .),
        query: %q(
          <#me> :namee "Gregg Kellogg"; foaf:name "Gregg Kellogg" .
        )
      },
      "cax-sco"   => {
        default: %q(<#me> a :Person .),
        query: %q(
          <#me> a :Person, foaf:Person .
        )
      },
      "cax-eqc1"   => {
        default: %q(<#me> a :Persone .),
        query: %q(
          <#me> a :Persone, foaf:Person .
        )
      },
      "cax-eqc2"   => {
        default: %q(<#me> a foaf:Person .),
        query: %q(
          <#me> a foaf:Person, :Persone .
        )
      },
    }.each do |test, elements|
      it test do
        mt = ExpansionTester.new(test)
        query = mt.load(elements)
        mt.send(:expand, mt.repo)
        expect(mt.graph).to pass_query(query, mt)
      end
    end
  end

  describe :expand do
    {
      "simple"   => {
        default: %q(<document> rdfa:usesVocabulary exp: .),
        "http://example.org/vocab#" => %q(
          exp:Person owl:equivalentClass foaf:Person .
        ),
        query: %q(<document> rdfa:usesVocabulary exp: .)
      },
      "prp-spo1"   => {
        default: %q(
          <document> rdfa:usesVocabulary exp: .
          <#me> exp:name "Gregg Kellogg" .
        ),
        "http://example.org/vocab#" => %q(
          exp:name rdfs:subPropertyOf foaf:name .
        ),
        query: %q(
          <document> rdfa:usesVocabulary exp: .
          <#me> exp:name "Gregg Kellogg";
            foaf:name "Gregg Kellogg" .
        )
      },
      "prp-eqp1"   => {
        default: %q(
          <document> rdfa:usesVocabulary exp: .
          <#me> exp:name "Gregg Kellogg" .
        ),
        "http://example.org/vocab#" => %q(
          exp:namee owl:equivalentProperty foaf:name .
        ),
        query: %q(
          <document> rdfa:usesVocabulary exp: .
          <#me> exp:namee "Gregg Kellogg";
            foaf:name "Gregg Kellogg" .
        )
      },
      "prp-eqp2"   => {
        default: %q(
          <document> rdfa:usesVocabulary exp: .
          <#me> foaf:name "Gregg Kellogg" .
        ),
        "http://example.org/vocab#" => %q(
          exp:name owl:equivalentProperty foaf:name .
        ),
        query: %q(
          <document> rdfa:usesVocabulary exp: .
          <#me> exp:namee "Gregg Kellogg";
            foaf:name "Gregg Kellogg" .
        )
      },
      "cax-sco"   => {
        default: %q(
          <document> rdfa:usesVocabulary exp: .
          <#me> a exp:Person .
        ),
        "http://example.org/vocab#" => %q(
          exp:Person rdfs:subClassOf foaf:Person .
        ),
        query: %q(
          <document> rdfa:usesVocabulary exp: .
          <#me> a exp:Person, foaf:Person .
        )
      },
      "cax-eqc1"   => {
        default: %q(
          <document> rdfa:usesVocabulary exp: .
          <#me> a exp:Persone .
        ),
        "http://example.org/vocab#" => %q(
          exp:Person owl:equivalentClass foaf:Person .
        ),
        query: %q(
          <document> rdfa:usesVocabulary exp: .
          <#me> a exp:Persone, foaf:Person .
        )
      },
      "cax-eqc2"   => {
        default: %q(
          <document> rdfa:usesVocabulary exp: .
          <#me> a foaf:Person .
        ),
        "http://example.org/vocab#" => %q(
          exp:Person owl:equivalentClass foaf:Person .
        ),
        query: %q(
          <document> rdfa:usesVocabulary exp: .
          <#me> a exp:Persone, foaf:Person .
        )
      }
    }.each do |test, elements|
      it test do
        mt = ExpansionTester.new(test)
        query = mt.load(elements)
        mt.expand(mt.repo)
        expect(mt.graph).to pass_query(query, mt)
      end
    end
  end
  
  describe :copy_properties do
    {
      "simple" => {
        default: %q(
          <> rdfa:copy _:ref .
          _:ref a rdfa:Pattern; rdf:value "Pattern" .
        ),
        query: %q(<> rdf:value "Pattern" .)
      },
      "chaining ref" => {
        default: %q(
          <> rdfa:copy _:ref .
          _:ref a rdfa:Pattern;
            rdf:value "Pattern";
            rdfa:copy _:ref2 .
          _:ref2 a rdfa:Pattern;
          rdf:value "Pattern2" .
        ),
        query: %q(<> rdf:value "Pattern", "Pattern2" .)
      }
    }.each do |test, elements|
      it test do
        mt = ExpansionTester.new(test)
        query = mt.load(elements)
        mt.copy_properties(mt.repo)
        expect(mt.graph).to pass_query(query, mt)
      end
    end
  end

  context "with empty graph" do
    it "returns an empty graph" do
      rdfa = %q(<http></http>)
      expect(parse(rdfa)).to be_equivalent_graph("", :trace => @debug)
    end
  end
  
  context "with graph not referencing vocabularies" do
    it "returns unexpanded input" do
      rdfa = %(
        <html prefix="doap: http://usefulinc.com/ns/doap#">
          <body about="" typeof="doap:Project">
            <p>Project description for <span property="doap:name">RDF::RDFa</span>.</p>
            <dl>
              <dt>Creator</dt><dd>
                <a href="http://greggkellogg.net/foaf#me"
                   rel="dc:creator">
                   Gregg Kellogg
                </a>
              </dd>
            </dl>
          </body>
        </html>
      )
      query = %(
        PREFIX doap: <http://usefulinc.com/ns/doap#>
        PREFIX dc:   <http://purl.org/dc/terms/>

        ASK WHERE {
          <> a doap:Project;
            doap:name "RDF::RDFa";
            dc:creator <http://greggkellogg.net/foaf#me> .
        }
      )
      expect(parse(rdfa)).to pass_query(query, trace: @debug)
    end
  end
  
  context "with @vocab" do
    it "returns unexpanded input" do
      rdfa = %(
        <html vocab="http://usefulinc.com/ns/doap#">
          <body about="" typeof="Project">
            <p>Project description for <span property="name">RDF::RDFa</span>.</p>
            <dl>
              <dt>Creator</dt><dd>
                <a href="http://greggkellogg.net/foaf#me"
                   rel="dc:creator">
                   Gregg Kellogg
                </a>
              </dd>
            </dl>
          </body>
        </html>
      )
      query = %(
        PREFIX doap: <http://usefulinc.com/ns/doap#>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX wn:   <http://xmlns.com/wordnet/1.6/>
        PREFIX foaf: <http://xmlns.com/foaf/0.1/>
        PREFIX rdfa: <http://www.w3.org/ns/rdfa#>
        PREFIX dc:   <http://purl.org/dc/terms/>

        ASK WHERE {
          <> a doap:Project, wn:Project, foaf:Project;
            rdfa:usesVocabulary <http://usefulinc.com/ns/doap#>;
            doap:name "RDF::RDFa";
            rdfs:label "RDF::RDFa";
            dc:creator <http://greggkellogg.net/foaf#me> .
        }
      )
      expect(parse(rdfa)).to pass_query(query, :trace => @debug)
    end
  end
  
  context "rdfa:Pattern" do
    {
      "to single id" =>
      [
        %q(
          <div>
            <div typeof="schema:Person">
              <link property="rdfa:copy" resource="_:a"/>
            </div>
            <p resource="_:a" typeof="rdfa:Pattern">Name: <span property="schema:name">Amanda</span></p>
          </div>
        ),
        %q(
          PREFIX schema: <http://schema.org/>
          ASK WHERE {[a schema:Person; schema:name "Amanda"]}
        )
      ],
      "to generate listed property values" =>
      [
        %q(
        <div>
          <div typeof="schema:Person">
            <p>My name is <span property="schema:name">Gregg</span></p>
            <link property="rdfa:copy" resource="_:surname"/>
          </div>
          <p resource="_:surname" typeof="rdfa:Pattern">My name is <span property="schema:name">Kellogg</span></p>
        </div>
        ),
        %q(
          PREFIX schema: <http://schema.org/>
          ASK WHERE {[ a schema:Person; schema:name "Gregg", "Kellogg"]}
        )
      ],
      "to single id with different types" =>
      [
        %q(
          <div>
            <div typeof="schema:Person">
              <link property="rdfa:copy" resource="_:a"/>
            </div>
            <div typeof="foaf:Person">
              <link property="rdfa:copy" resource="_:a"/>
            </div>
            <p resource="_:a" typeof="rdfa:Pattern">Name: <span property="schema:name foaf:name">Amanda</span></p>
          </div>
        ),
        %q(
          PREFIX foaf: <http://xmlns.com/foaf/0.1/>
          PREFIX schema: <http://schema.org/>
          ASK WHERE{
            [ a schema:Person; schema:name "Amanda"; foaf:name "Amanda"] .
            [ a foaf:Person; schema:name "Amanda"; foaf:name "Amanda"] .
          }
        )
      ],
      "to multiple prototypes" =>
      [
        %q(
          <div>
            <div typeof="schema:Person">
              <link property="rdfa:copy" resource="_:a"/>
              <link property="rdfa:copy" resource="_:b"/>
            </div>
            <p resource="_:a" typeof="rdfa:Pattern">Name: <span property="schema:name">Amanda</span></p>
            <p resource="_:b" typeof="rdfa:Pattern"><span property="schema:band">Jazz Band</span></p>
          </div>
        ),
        %q(
          PREFIX schema: <http://schema.org/>
          ASK WHERE{
            [ a schema:Person;
              schema:name "Amanda";
              schema:band "Jazz Band";
            ]
          }
        )
      ],
      "with chaining" =>
      [
        %q(
          <div>
            <div typeof="schema:Person">
              <link property="rdfa:copy" resource="_:a"/>
              <link property="rdfa:copy" resource="_:b"/>
            </div>
            <p resource="_:a" typeof="rdfa:Pattern">Name: <span property="schema:name">Amanda</span></p>
            <div resource="_:b" typeof="rdfa:Pattern">
              <div property="schema:band" typeof=" schema:MusicGroup">
                <link property="rdfa:copy" resource="_:c"/>
              </div>
            </div>
            <div resource="_:c" typeof="rdfa:Pattern">
             <p>Band: <span property="schema:name">Jazz Band</span></p>
             <p>Size: <span property="schema:size">12</span> players</p>
            </div>
          </div>
        ),
        %q(
          PREFIX schema: <http://schema.org/>
          ASK WHERE{
            [ a schema:Person;
              schema:name "Amanda" ;
              schema:band [
                a schema:MusicGroup;
                schema:name "Jazz Band";
                schema:size "12"
              ]
            ]
          }
        )
      ],
      "shared" =>
      [
        %q(
          <div>
            <div typeof=""><link property="rdfa:copy" resource="_:a"/></div>
            <div typeof=""><link property="rdfa:copy" resource="_:a"/></div>
            <div resource="_:a" typeof="rdfa:Pattern">
              <div property="schema:refers-to" typeof="">
                <span property="schema:name">Amanda</span>
              </div>
            </div>
          </div>
        ),
        %q(
          PREFIX schema: <http://schema.org/>
          ASK WHERE{
            [ schema:refers-to ?a ] .
            [ schema:refers-to ?a ] .
            ?a schema:name "Amanda" .
          }
        )
          
      ],
    }.each do |title, (input, query)|
      it title do
        expect(parse(input)).to pass_query(query,
          base_uri: "http://example.com/",
          trace: @debug)
      end
    end
  end

  def parse(input, options = {})
    @debug = options[:debug] || []
    RDF::Graph.new << RDF::RDFa::Reader.new(input, options.merge(
      debug: @debug, vocab_expansion: true
    ))
  end
end
