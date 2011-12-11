require 'rspec/matchers'

RSpec::Matchers.define :have_xpath do |xpath, value, trace|
  xpath = xpath.gsub("xhtml:", "") # Using HTML parser, no namespaces needed
  match do |actual|
    @doc = Nokogiri::HTML.parse(actual)
    @doc.should be_a(Nokogiri::HTML::Document)
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
    msg = "expected that #{xpath.inspect} would be #{value.inspect} in:\n" + actual.to_s
    msg += "was: #{@doc.root.at_xpath(xpath, @namespaces)}"
    msg +=  "\nDebug:#{trace.join("\n")}" if trace
    msg
  end
  
  failure_message_for_should_not do |actual|
    msg = "expected that #{xpath.inspect} would not be #{value.inspect} in:\n" + actual.to_s
    msg +=  "\nDebug:#{trace.join("\n")}" if trace
    msg
  end
end

def normalize(graph)
  case graph
  when RDF::Queryable then graph
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

Info = Struct.new(:about, :information, :trace, :compare, :inputDocument, :outputDocument, :expectedResults, :format, :title)

RSpec::Matchers.define :be_equivalent_graph do |expected, info|
  match do |actual|
    @info = if info.respond_to?(:about)
      info
    elsif info.is_a?(Hash)
      identifier = info[:identifier] || expected.is_a?(RDF::Graph) ? expected.context : info[:about]
      trace = info[:trace]
      trace = trace.join("\n") if trace.is_a?(Array)
      i = Info.new(identifier, info[:information] || "", trace, info[:compare])
      i.format = info[:format]
      i
    else
      Info.new(expected.is_a?(RDF::Graph) ? expected.context : info, info.to_s)
    end
    @info.format ||= :ntriples
    @expected = normalize(expected)
    @actual = normalize(actual)
    @actual.isomorphic_with?(@expected) rescue false
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
    "Unsorted Expected:\n#{@expected.dump(@info.format, :standard_prefixes => true)}" +
    "Unsorted Results:\n#{@actual.dump(@info.format, :standard_prefixes => true)}" +
    (@info.trace ? "\nDebug:\n#{@info.trace}" : "")
  end  
end

RSpec::Matchers.define :pass_query do |expected, info|
  match do |actual|
    if info.respond_to?(:information)
      @info = info
    elsif info.is_a?(Hash)
      trace = info[:trace]
      trace = trace.join("\n") if trace.is_a?(Array)
      @info = Info.new(info[:identifier] || "", info[:information] || "", trace, info[:compare])
      @info[:expectedResults] = info[:expectedResults] || RDF::Literal::Boolean.new(true)
    elsif info.is_a?(Array)
      @info = Info.new()
      @info[:trace] = info.join("\n")
      @info[:expectedResults] = RDF::Literal::Boolean.new(true)
    else
      @info = Info.new()
      @info[:expectedResults] = RDF::Literal::Boolean.new(true)
    end

    @expected = expected.respond_to?(:read) ? expected.read : expected
    @expected = @expected.force_encoding("utf-8") if @expected.respond_to?(:force_encoding)

    require 'sparql'
    query = SPARQL.parse(@expected)
    actual = actual.force_encoding("utf-8") if actual.respond_to?(:force_encoding)
    @results = query.execute(actual)

    @results.should == @info.expectedResults
  end
  
  failure_message_for_should do |actual|
    "#{@info.inspect + "\n"}" +
    "#{@info.title + "\n" if @info.title}" +
    if @results.nil?
      "Query failed to return results"
    elsif !@results.is_a?(RDF::Literal::Boolean)
      "Query returned non-boolean results"
    elsif @info.expectedResults != @results
      "Query returned false (expected #{@info.expectedResults})"
    else
      "Query returned true (expected #{@info.expectedResults})"
    end +
    "\n#{@expected}" +
    "\nResults:\n#{@actual.dump(:ttl, :standard_prefixes => true)}" +
    "\nDebug:\n#{@info.trace}"
  end  
end
