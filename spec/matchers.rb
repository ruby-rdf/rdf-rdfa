require 'rspec/matchers'

RSpec::Matchers.define :have_xpath do |xpath, value|
  match do |actual|
    @doc = Nokogiri::XML.parse(actual)
    @doc.should be_a(Nokogiri::XML::Document)
    @doc.root.should be_a(Nokogiri::XML::Element)
    @namespaces = @doc.namespaces.merge("xhtml" => "http://www.w3.org/1999/xhtml", "xml" => "http://www.w3.org/XML/1998/namespace")
    case value
    when false
      @doc.root.at_xpath(xpath, @namespaces).should be_nil
    when true
      @doc.root.at_xpath(xpath, @namespaces).should_not be_nil
    when Array
      @doc.root.at_xpath(xpath, @namespaces).to_s.split(" ").should include(*value)
    when Regexp
      @doc.root.at_xpath(xpath, @namespaces).to_s.should =~ value
    else
      @doc.root.at_xpath(xpath, @namespaces).to_s.should == value
    end
  end
  
  failure_message_for_should do |actual|
    msg = "expected to that #{xpath.inspect} would be #{value.inspect} in:\n" + actual.to_s
    msg += "was: #{@doc.root.at_xpath(xpath, @namespaces)}"
  end
end

def normalize(graph)
  case graph
  when RDF::Graph then graph
  when IO, StringIO
    RDF::Graph.new.load(graph, :base_uri => @info.about)
  else
    # Figure out which parser to use
    g = RDF::Graph.new
    reader_class = detect_format(graph)
    reader_class.new(graph, :base_uri => @info.about).each {|s| g << s}
    g
  end
end

Info = Struct.new(:about, :information, :trace, :compare, :inputDocument, :outputDocument)

RSpec::Matchers.define :be_equivalent_graph do |expected, info|
  match do |actual|
    @info = if info.respond_to?(:about)
      info
    elsif info.is_a?(Hash)
      identifier = info[:identifier] || expected.is_a?(RDF::Graph) ? expected.context : info[:about]
      trace = info[:trace]
      trace = trace.join("\n") if trace.is_a?(Array)
      Info.new(identifier, info[:information] || "", trace, info[:compare])
    else
      Info.new(expected.is_a?(RDF::Graph) ? expected.context : info, info.to_s)
    end
    @expected = normalize(expected)
    @actual = normalize(actual)
    @actual.isomorphic_with?(@expected)
  end
  
  failure_message_for_should do |actual|
    info = @info.respond_to?(:information) ? @info.information : @info.inspect
    if @expected.is_a?(RDF::Graph) && @actual.size != @expected.size
      "Graph entry count differs:\nexpected: #{@expected.size}\nactual:   #{@actual.size}"
    elsif @expected.is_a?(Array) && @actual.size != @expected.length
      "Graph entry count differs:\nexpected: #{@expected.length}\nactual:   #{@actual.size}"
    else
      "Graph differs"
    end +
    "\n#{info + "\n" unless info.empty?}" +
    (@info.inputDocument ? "Input file: #{@info.inputDocument}\n" : "") +
    (@info.outputDocument ? "Output file: #{@info.outputDocument}\n" : "") +
    "Unsorted Expected:\n#{@expected.dump(:ntriples)}" +
    "Unsorted Results:\n#{@actual.dump(:ntriples)}" +
    (@info.trace ? "\nDebug:\n#{@info.trace}" : "")
  end  
end

RSpec::Matchers.define :pass_query do |expected, info|
  match do |actual|
    @expected_results = info.respond_to?(:expectedResults) ? info.expectedResults : true
    if $redland_enabled
      query = Redland::Query.new(expected)

      model = Redland::Model.new
      ntriples_parser = Redland::Parser.ntriples
      ntriples_parser.parse_string_into_model(model, actual.dump(:ntriples), "http://www.w3.org/2006/07/SWD/RDFa/testsuite/xhtml1-testcases/")

      @results = query.execute(model)
      #puts "Redland query results: #{@results.inspect}"
      if @expected_results && @results
        @results.is_boolean? && @results.get_boolean?
      else
        @results.nil? || @results.is_boolean? && !@results.get_boolean?
      end
    else
      pending("Query skipped, Redland not installed") { fail }
    end
  end
  
  failure_message_for_should do |actual|
    information = info.respond_to?(:information) ? info.information : ""
    "#{information + "\n" unless information.empty?}" +
    if @results.nil?
      "Query failed to return results"
    elsif !@results.is_boolean?
      "Query returned non-boolean results"
    elsif @expected_results
      "Query returned false"
    else
      "Query returned true (expected false)"
    end +
    "\n#{expected}" +
    "\nResults:\n#{@actual.dump(:ntriples)}" +
    "\nDebug:\n#{info.trace}"
  end  
end
