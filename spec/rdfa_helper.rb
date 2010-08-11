require 'rdf/rdfxml'
autoload :YAML, "yaml"
autoload :CGI, 'cgi'

RDFA_DIR = File.join(File.dirname(__FILE__), 'rdfa-test-suite')
RDFA_NT_DIR = File.join(File.dirname(__FILE__), 'rdfa-triples')
RDFA_MANIFEST_URL = "http://rdfa.digitalbazaar.com/test-suite/"
RDFA_TEST_CASE_URL = "#{RDFA_MANIFEST_URL}test-cases/"

class SparqlException < IOError; end

module RdfaHelper
  # Class representing test cases in format http://www.w3.org/2006/03/test-description#
  class TestCase
    HTMLRE = Regexp.new('([0-9]{4,4})\.xhtml')
    TCPATHRE = Regexp.compile('\$TCPATH')
    
    attr_accessor :about
    attr_accessor :name
    attr_accessor :contributor
    attr_accessor :title
    attr_accessor :informationResourceInput
    attr_accessor :informationResourceResults
    attr_accessor :purpose
    attr_accessor :reviewStatus
    attr_accessor :suite
    attr_accessor :specificationReference
    attr_accessor :expectedResults
    attr_accessor :parser
    attr_accessor :debug
    
    @@suite = ""
    
    def initialize(statements, suite)
      self.suite = suite
      self.expectedResults = true
      statements.each do |statement|
        next if statement.subject.is_a?(RDF::Node)
        pred = statement.predicate.to_s.split(/[\#\/]/).last
        obj  = statement.object.is_a?(RDF::Literal) ? statement.object.value : statement.object.to_s
        
        puts "#{pred}: #{obj}" if $DEBUG

        unless self.about
          self.about = statement.subject
          self.name = self.about.to_s.split(/[\#\/]/).last || self.about
        end

        if pred == "expectedResults"
          self.expectedResults = obj == "true"
          #puts "expectedResults = #{statement.object.literal.value}"
        elsif self.respond_to?("#{pred}=")
          self.send("#{pred}=", obj)
        end
      end
    end
    
    def inspect
      "[Test Case " + %w(
        about
        name
        contributor
        title
        informationResourceInput
        informationResourceResults
        purpose
        reviewStatus
        specificationReference
        expectedResults
      ).map {|a| v = self.send(a); "#{a}='#{v}'" if v}.compact.join(", ") +
      "]"
    end
    
    def status
      reviewStatus.to_s.split("#").last
    end
    
    def compare; :graph; end
    
    def information
      %w(purpose specificationReference).map {|a| v = self.send(a); "#{a}: #{v}" if v}.compact.join("\n")
    end
    
    def tcpath
      RDFA_TEST_CASE_URL + (suite == "xhtml" ? "xhtml1" : suite)
    end
    
    # Read in file, and apply modifications to create a properly formatted HTML
    def input
      f = self.inputDocument
      found_head = false
      namespaces = ""
      body = File.readlines(File.join(RDFA_DIR, "tests", f)).map do |line|
        found_head ||= line.match(/<head/)
        if found_head
          line.chop
        else
          namespaces << line
          nil
        end
      end.compact.join("\n")

      namespaces.chop!  # Remove trailing newline
      
      case suite
      when "xhtml"
        head = "" +
        %(<?xml version="1.0" encoding="UTF-8"?>\n) +
        %(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">\n) +
        %(<html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.0"\n)
        head + "#{namespaces}>\n#{body.gsub(TCPATHRE, tcpath)}\n</html>"
      when "xhtml11"
        head = "" +
        %(<?xml version="1.0" encoding="UTF-8"?>\n) +
        %(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.1//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-2.dtd">\n) +
        %(<html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.1"\n)
        head + "#{namespaces}>\n#{body.gsub(TCPATHRE, tcpath)}\n</html>"
      when "html4"
        head ="" +
        %(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">\n) +
        %(<html version="XHTML+RDFa 1.0"\n)
        head + "#{namespaces}>\n#{body.gsub(TCPATHRE, tcpath).gsub(HTMLRE, '\1.html')}\n</html>"
      when "html5"
        head = "<!DOCTYPE html>\n"
        head += namespaces.empty? ? %(<html version="HTML+RDFa 1.0">) : "<html\n#{namespaces}>"
        head + "\n#{body.gsub(TCPATHRE, tcpath).gsub(HTMLRE, '\1.html')}\n</html>"
      else
        nil
      end
    end
    
    # Read in file, and apply modifications reference either .html or .xhtml
    def results
      f = self.name + ".sparql"
      body = File.read(File.join(RDFA_DIR, "tests", f)).gsub(TCPATHRE, tcpath)
      
      suite =~ /xhtml/ ? body : body.gsub(HTMLRE, '\1.html')
    end
    
    def triples
      f = self.name + ".nt"
      body = File.read(File.join(RDFA_NT_DIR, f)).gsub(TCPATHRE, tcpath)
      suite =~ /xhtml/ ? body : body.gsub(HTMLRE, '\1.html')
    end
    
    def inputDocument; self.name + ".txt"; end
    def outputDocument; self.name + ".sparql"; end

    # Run test case, yields input for parser to create triples
    def run_test
      rdfa_string = input
      
      # Run
      graph = yield(rdfa_string)

      query_string = results

      triples = self.triples rescue nil
      
      if (query_string.match(/UNION|OPTIONAL/) || title.match(/XML/)) && triples
        # Check triples, as Rasql doesn't implement UNION
        graph.should be_equivalent_graph(triples, self)
      elsif $redland_enabled
        # Run SPARQL query
        graph.should pass_query(query_string, self)
      else
        raise SparqlException, "Query skipped, Redland not installed"
      end

      graph.to_rdfxml.should be_valid_xml
    end
    
    def trace
      @debug.to_a.join("\n")
    end
    
    def self.test_cases(suite)
      @test_cases = [] unless @suite == suite
      return @test_cases unless @test_cases.empty?
      
      @suite = suite # Process the given test suite
      @manifest_url = "#{RDFA_MANIFEST_URL}#{suite}-manifest.rdf"
      
      manifest_file = File.join(RDFA_DIR, "#{suite}-manifest.rdf")
      yaml_file = File.join(File.dirname(__FILE__), "#{suite}-manifest.yml")
      
      @test_cases = unless File.file?(yaml_file)
        puts "parse #{manifest_file} @#{Time.now}"
        graph = RDF::Graph.load(manifest_file, :base_uri => @manifest_url)
        puts "parsed #{graph.size} statements @#{Time.now}"

        graph.subjects.map do |subj|
          t = TestCase.new(graph.query(:subject => subj), suite)
          t.name ? t : nil
        end.
          compact.
          sort_by{|t| t.name.to_s}
      else
        # Read tests from Manifest.yml
        self.from_yaml(yaml_file)
      end
    end
    
    def self.to_yaml(suite, file)
      test_cases = self.test_cases(suite)
      puts "write test cases to #{file}"
      File.open(file, 'w') do |out|
        YAML.dump(test_cases, out )
      end
    end
    
    def self.from_yaml(file)
      YAML::add_private_type("RdfaHelper::TestCase") do |type, val|
        TestCase.new( val )
      end
      File.open(file, 'r') do |input|
        @test_cases = YAML.load(input)
      end
    end
  end
end
