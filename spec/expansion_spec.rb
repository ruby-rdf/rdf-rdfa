$:.unshift "."
require 'spec_helper'

# Class for abstract testing of module
class ExpansionTester
  include RDF::RDFa::Expansion
  include RDF::Enumerable

  attr_reader :about, :information, :repo, :inputDocument, :outputDocument, :options
  attr :format, true

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

  def add_debug(node, message = "")
    message = message + yield if block_given?
    @trace ||= []
    @trace << "#{node}: #{message}"
    #STDERR.puts "#{node}: #{message}"
  end
  
  def trace; @trace.join("\n"); end
  
  def load(elements)
    @@vocab_repo = RDF::Repository.new
    @options = {:vocab_repository => @@vocab_repo}
    result = nil
    elements.each do |context, ttl|
      case context
      when :default
        @inputDocument = ttl
        @repo << parse(ttl)
      when :result
        @outputDocument = ttl
        result = parse(ttl)
      else
        parse(ttl).each do |st|
          st.context = RDF::URI(context.to_s)
          @@vocab_repo << st
        end
      end
    end
    
    result
  end
  
  def add_vocabs_to_repo(repo)
    repo.insert(@@vocab_repo)
  end
  
  def parse(ttl)
    RDF::Graph.new << RDF::Turtle::Reader.new(ttl, :prefixes => {
      :foaf => RDF::FOAF.to_uri,
      :rdf  => RDF.to_uri,
      :rdfa => RDF::RDFA.to_uri,
      :rdfs => RDF::RDFS.to_uri,
      :xsd  => RDF::XSD.to_uri,
      :ex   => RDF::URI("http://example.org/vocab#"),
      nil   => "http://example.org/",
    })
  end
end

describe RDF::RDFa::Expansion do
  
  before(:each) do
    RDF::RDFa::Reader.send(:class_variable_set, :@@vocab_repo, nil)
  end

  describe :rdfs_entailment do
    {
      "empty"   => {
        :default => %q(),
        :result => %q()
      },
      "simple"   => {
        :default => %q(:a a rdfs:Class .),
        :result => %q(:a a rdfs:Class .)
      },
      "rule5"   => {
        :default => %q(<#me> :name "Gregg Kellogg" .),
        :rules => %q(
          :name rdfs:subPropertyOf foaf:name .
          foaf:name rdfs:subPropertyOf rdfs:label .
        ),
        :result => %q(
          <#me> :name "Gregg Kellogg"; foaf:name "Gregg Kellogg"; rdfs:label "Gregg Kellogg" .
        )
      },
      "rule7"   => {
        :default => %q(<#me> :name "Gregg Kellogg" .),
        :rules => %q(
          :name rdfs:subPropertyOf foaf:name .
        ),
        :result => %q(
          <#me> :name "Gregg Kellogg"; foaf:name "Gregg Kellogg" .
        )
      },
      "rule9"   => {
        :default => %q(<#me> a foaf:Person .),
        :rules => %q(
          foaf:Person rdfs:subClassOf foaf:Agent .
        ),
        :result => %q(
          <#me> a foaf:Person, foaf:Agent .
        )
      },
      "rule11"   => {
        :default => %q(<#me> a foaf:Person .),
        :rules => %q(
          foaf:Person rdfs:subClassOf foaf:Agent .
          foaf:Agent rdfs:subClassOf rdfs:Resource .
        ),
        :result => %q(
          <#me> a foaf:Person, foaf:Agent, rdfs:Resource .
        )
      },
    }.each do |test, elements|
      it test do
        mt = ExpansionTester.new(test)
        result = mt.load(elements)
        mt.add_vocabs_to_repo(mt.repo)
        mt.send(:rdfs_entailment, mt.repo)
        mt.graph.should be_equivalent_graph(result, mt)
      end
    end
  end

  describe :expand do
    {
      "simple"   => {
        :default => %q(<document> rdfa:hasVocabulary ex: .),
        :result => %q(<document> rdfa:hasVocabulary ex: .)
      },
      "rule5"   => {
        :default => %q(
          <document> rdfa:hasVocabulary ex: .
          <#me> ex:name "Gregg Kellogg" .
        ),
        "http://example.org/vocab#" => %q(
          ex:name rdfs:subPropertyOf foaf:name .
          foaf:name rdfs:subPropertyOf rdfs:label .
        ),
        :result => %q(
          <document> rdfa:hasVocabulary ex: .
          <#me> ex:name "Gregg Kellogg";
            foaf:name "Gregg Kellogg";
            rdfs:label "Gregg Kellogg" .
        )
      },
      "rule7"   => {
        :default => %q(
          <document> rdfa:hasVocabulary ex: .
          <#me> ex:name "Gregg Kellogg" .
        ),
        "http://example.org/vocab#" => %q(
          ex:name rdfs:subPropertyOf foaf:name .
        ),
        :result => %q(
          <document> rdfa:hasVocabulary ex: .
          <#me> ex:name "Gregg Kellogg";
            foaf:name "Gregg Kellogg" .
        )
      },
      "rule9"   => {
        :default => %q(
          <document> rdfa:hasVocabulary ex: .
          <#me> a ex:Person .
        ),
        "http://example.org/vocab#" => %q(
          ex:Person rdfs:subClassOf foaf:Person .
        ),
        :result => %q(
          <document> rdfa:hasVocabulary ex: .
          <#me> a ex:Person, foaf:Person .
        )
      },
      "rule11"   => {
        :default => %q(
          <document> rdfa:hasVocabulary ex: .
          <#me> a ex:Person .
        ),
        "http://example.org/vocab#" => %q(
          ex:Person rdfs:subClassOf foaf:Person .
          foaf:Person rdfs:subClassOf foaf:Agent .
        ),
        :result => %q(
          <document> rdfa:hasVocabulary ex: .
          <#me> a ex:Person, foaf:Person, foaf:Agent .
        )
      },
    }.each do |test, elements|
      it test do
        mt = ExpansionTester.new(test)
        result = mt.load(elements)
        vocab = RDF::URI("http://example.org/vocab#")
        graph = RDF::Graph.new
        RDF::Graph.should_receive(:new).and_return(graph)
        graph = mt.expand
        graph.should be_equivalent_graph(result, mt)
      end
    end
  end
  
  context "with empty graph" do
    it "returns an empty graph" do
      rdfa = %q(<http></http>)
      parse(rdfa).should be_equivalent_graph("", :trace => @debug)
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
      ttl = %(
        @prefix doap: <http://usefulinc.com/ns/doap#> .
        @prefix dc:   <http://purl.org/dc/terms/> .

        <> a doap:Project;
          doap:name "RDF::RDFa";
          dc:creator <http://greggkellogg.net/foaf#me> .
      )
      parse(rdfa).should be_equivalent_graph(ttl, :trace => @debug)
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
      ttl = %(
        @prefix doap: <http://usefulinc.com/ns/doap#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        @prefix wn:   <http://xmlns.com/wordnet/1.6/> .
        @prefix foaf: <http://xmlns.com/foaf/0.1/> .
        @prefix rdfa: <http://www.w3.org/ns/rdfa#> .
        @prefix dc:   <http://purl.org/dc/terms/> .

        <> a doap:Project, wn:Project, foaf:Project;
          rdfa:hasVocabulary <http://usefulinc.com/ns/doap#>;
          doap:name "RDF::RDFa";
          rdfs:label "RDF::RDFa";
          dc:creator <http://greggkellogg.net/foaf#me> .
      )
      parse(rdfa).should be_equivalent_graph(ttl, :trace => @debug)
    end
  end
  
  def parse(input, options = {})
    @debug = options[:debug] || []
    RDF::Graph.new << RDF::RDFa::Reader.new(input, options.merge(:debug => @debug, :expand => true))
  end
end
