module Matchers
  class BeEquivalentGraph
    Info = Struct.new(:about, :information, :trace, :compare, :inputDocument, :outputDocument)
    def normalize(graph)
      case @info.compare
      when :array
        array = case graph
        when Graph, Parser
          graph = graph.graph if graph.respond_to?(:graph)
          anon = "a"
          anon_ctx = {}
          graph.triples.collect {|triple| triple.to_ntriples }.each do |t|
            t.gsub(/_:nbn\d+[a-z]+N/, "_:").
            gsub!(/_:bn\d+[a-z]+/) do |bn|
              # Normalize anon BNodes
              if anon_ctx[bn]
                anon_ctx[bn]
              else
                anon_ctx[bn] = anon
                anon = anon.succ
              end
              "_:#{anon_ctx[bn]}"
            end
          end.sort
        when Array
          graph.sort
        else
          graph.to_s.split("\n").
            map {|t| t.gsub(/^\s*(.*)\s*$/, '\1')}.
            reject {|t2| t2.match(/^\s*$/)}.
            compact.
            sort.
            uniq
        end
        
        # Implement to_ntriples on array, to simplify logic later
        def array.to_ntriples; self.join("\n") + "\n"; end
        array
      else
        case graph
        when Graph then graph
        when Parser then graph.graph
        when IO, StringIO
          Parser.parse(graph, @info.about)
        else
          parser = Parser.new(:struct => true)
          fmt = parser.detect_format(graph.to_s)
          parser.parse(graph.to_s, @info.about, :type => fmt)
        end
      end
    end
    
    def initialize(expected, info)
      @info = if info.respond_to?(:about)
        info
      elsif info.is_a?(Hash)
        identifier = info[:identifier] || expected.is_a?(Graph) ? expected.identifier : info[:about]
        Info.new(identifier, info[:information] || "", info[:trace], info[:compare])
      else
        Info.new(expected.is_a?(Graph) ? expected.identifier : info, info.to_s)
      end
      @expected = normalize(expected)
    end

    def matches?(actual)
      @actual = normalize(actual)
      @actual == @expected
    end

    def failure_message_for_should
      info = @info.respond_to?(:information) ? @info.information : ""
      if @expected.is_a?(Graph) && @actual.size != @expected.size
        "Graph entry count differs:\nexpected: #{@expected.size}\nactual:   #{@actual.size}"
      elsif @expected.is_a?(Array) && @actual.size != @expected.length
        "Graph entry count differs:\nexpected: #{@expected.length}\nactual:   #{@actual.size}"
      elsif @expected.is_a?(Graph) && @actual.identifier != @expected.identifier
        "Graph identifiers differ:\nexpected: #{@expected.identifier}\nactual:   #{@actual.identifier}"
      else
        "Graph differs#{@info.compare == :array ? '(array)' : ''}\n"
      end +
      "\n#{info + "\n" unless info.empty?}" +
      (@info.inputDocument ? "Input file: #{@info.inputDocument}\n" : "") +
      (@info.outputDocument ? "Output file: #{@info.outputDocument}\n" : "") +
      "Unsorted Expected:\n#{@expected.to_ntriples}" +
      "Unsorted Results:\n#{@actual.to_ntriples}" +
      (@info.trace ? "\nDebug:\n#{@info.trace}" : "")
    end
    def negative_failure_message
      "Graphs do not differ\n"
    end
  end
  
  def be_equivalent_graph(expected, info = nil)
    BeEquivalentGraph.new(expected, info)
  end

  # Run expected SPARQL query against actual
  if $redland_enabled
    class PassQuery
      def initialize(expected, info)
        @expected = expected
        @query = Redland::Query.new(expected)
        @info = info
      end
      def matches?(actual)
        @actual = actual
        @expected_results = @info.respond_to?(:expectedResults) ? @info.expectedResults : true
        model = Redland::Model.new
        ntriples_parser = Redland::Parser.ntriples
        ntriples_parser.parse_string_into_model(model, actual.to_ntriples, "http://www.w3.org/2006/07/SWD/RDFa/testsuite/xhtml1-testcases/")

        @results = @query.execute(model)
        #puts "Redland query results: #{@results.inspect}"
        if @expected_results
          @results.is_boolean? && @results.get_boolean?
        else
          @results.nil? || @results.is_boolean? && !@results.get_boolean?
        end
      end
      def failure_message_for_should
        info = @info.respond_to?(:information) ? @info.information : ""
        "#{info + "\n" unless info.empty?}" +
        if @results.nil?
          "Query failed to return results"
        elsif !@results.is_boolean?
          "Query returned non-boolean results"
        elsif @expected_results
          "Query returned false"
        else
          "Query returned true (expected false)"
        end +
        "\n#{@expected}" +
        "\n#{@info.input}" +
        "\nResults:\n#{@actual.to_ntriples}" +
        "\nDebug:\n#{@info.trace}"
      end
    end

    def pass_query(expected, info = "")
      PassQuery.new(expected, info)
    end
  else
    def pass_query(expect, info = ""); false; end
  end

  class BeValidXML
    def initialize(info)
      @info = info
    end
    def matches?(actual)
      @actual = actual
      @doc = Nokogiri::XML.parse(actual)
      @results = @doc.validate
      @results.nil?
    rescue
      false
    end
    def failure_message_for_should
      "#{@info + "\n" unless @info.empty?}" +
      if @doc.nil?
        "did not parse"
      else
        "\n#{@results}" +
        "\nParsed:\n#{@doc}"
      end   +
        "\nActual:\n#{@actual}"
    end
  end
  
  def be_valid_xml(info = "")
    BeValidXML.new(info)
  end

  class BeEquivalentXML
    def initialize(expected, info)
      @expected = expected
      @info = info
    end
    
    def matches?(actual)
      @actual = actual

      a = @actual.index("<") == 0 ? @actual : "<foo>#{@actual}</foo>"
      e = @expected.index("<") == 0 ? @expected : "<foo>#{@expected}</foo>"
      a_hash = ActiveSupport::XmlMini.parse(a)
      e_hash = ActiveSupport::XmlMini.parse(e)
      a_hash == e_hash
    rescue
      puts $!
      @fault = $!.message
      false
    end

    def failure_message_for_should
      "#{@info + "\n" unless @info.empty?}" +
      "Fault: #{@fault + "\n" if @fault}" +
      "Expected:#{@expected}\n" +
      "Actual:#{@actual}"
    end
  end
  
  def be_equivalent_xml(expected, info = "")
    BeEquivalentXML.new(expected, info)
  end
end
