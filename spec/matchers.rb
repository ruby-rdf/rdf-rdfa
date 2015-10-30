require 'rspec/matchers'

RSpec::Matchers.define :have_xpath do |path, value, debug|
  match do |actual|
    root = RDF::RDFa::Reader.new(actual).root
    return false unless root
    namespaces = root.namespaces.inject({}) {|memo, (k,v)| memo[k.to_s.sub(/xmlns:?/, '')] = v; memo}.
      merge("xhtml" => "http://www.w3.org/1999/xhtml", "xml" => "http://www.w3.org/XML/1998/namespace")
    @result = root.at_xpath(path, namespaces) rescue false
    case value
    when false
      @result.nil?
    when true
      !@result.nil?
    when Array
      @result.to_s.split(" ").include?(*value)
    when Regexp
      @result.to_s =~ value
    else
      @result.to_s == value
    end
  end
  
  failure_message do |actual|
    msg = "expected that #{path.inspect}\nwould be: #{value.inspect}"
    msg += "\n     was: #{@result}"
    msg += "\nsource:" + actual
    msg +=  "\nDebug:#{Array(debug).join("\n")}" if debug
    msg
  end

  failure_message_when_negated do |actual|
    msg = "expected that #{path.inspect}\nwould not be #{value.inspect}"
    msg += "\nsource:" + actual
    msg +=  "\nDebug:#{Array(debug).join("\n")}" if debug
    msg
  end
end

def normalize(graph)
  case graph
  when RDF::Queryable then graph
  when IO, StringIO
    RDF::Graph.new.load(graph, base_uri: @info.about)
  else
    # Figure out which parser to use
    g = RDF::Repository.new
    reader_class = detect_format(graph)
    reader_class.new(graph, base_uri: @info.about).each {|s| g << s}
    g
  end
end

Info = Struct.new(:about, :num, :trace, :compare, :inputDocument, :outputDocument, :expectedResults, :format, :title)

RSpec::Matchers.define :be_equivalent_graph do |expected, info|
  match do |actual|
    @info = if info.respond_to?(:about)
      info
    elsif info.is_a?(Hash)
      identifier = expected.is_a?(RDF::Graph) ? expected.graph_name : info[:about]
      trace = info[:trace]
      trace = trace.join("\n") if trace.is_a?(Array)
      i = Info.new(identifier, "0000", trace, info[:compare])
      i.format = info[:format]
      i
    else
      Info.new(expected.is_a?(RDF::Graph) ? expected.graph_name : info, "0000", info.to_s)
    end
    @info.format ||= :ttl
    @expected = normalize(expected)
    @actual = normalize(actual)
    @actual.isomorphic_with?(@expected) rescue false
  end
  
  failure_message do |actual|
    info = @info.respond_to?(:about) ? @info.about : @info.inspect
    if @expected.is_a?(RDF::Enumerable) && @actual.size != @expected.size
      "Graph entry count differs:\nexpected: #{@expected.size}\nactual:   #{@actual.size}"
    elsif @expected.is_a?(Array) && @actual.size != @expected.length
      "Graph entry count differs:\nexpected: #{@expected.length}\nactual:   #{@actual.size}"
    else
      "Graph differs"
    end +
    "\n#{info + "\n" unless info.to_s.empty?}" +
    (@info.inputDocument ? "Input file: #{@info.inputDocument}\n" : "") +
    (@info.outputDocument ? "Output file: #{@info.outputDocument}\n" : "") +
    "Expected:\n#{@expected.dump(@info.format, standard_prefixes: true)}" +
    "Results:\n#{@actual.dump(@info.format, standard_prefixes: true)}" +
    (@info.trace ? "\nDebug:\n#{@info.trace}" : "")
  end  
end

RSpec::Matchers.define :pass_query do |expected, info|
  match do |actual|
    if info.respond_to?(:about)
      @info = info
    elsif info.is_a?(Hash)
      trace = info[:trace]
      trace = trace.join("\n") if trace.is_a?(Array)
      @info = Info.new(info[:about] || "", "", trace, info[:compare])
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

    @results == @info.expectedResults
  end

  failure_message do |actual|
    "#{@info.inspect + "\n"}" +
    "#{@info.num + "\n" if @info.respond_to?(:num) && @info.num}" +
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
    "\nResults:\n#{@actual.dump(:ttl, standard_prefixes: true)}" +
    "\nDebug:\n#{@info.trace}"
  end  

  failure_message_when_negated do |actual|
    "#{@info.inspect + "\n"}" +
    "#{@info.num + "\n" if @info.num}" +
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
    "\nResults:\n#{@actual.dump(:ttl, standard_prefixes: true)}" +
    "\nDebug:\n#{@info.trace}"
  end  
end

RSpec::Matchers.define :produce do |expected, info|
  match do |actual|
    actual == expected
  end
  
  failure_message do |actual|
    "Expected: #{expected.inspect}\n" +
    "Actual  : #{actual.inspect}\n" +
    "Processing results:\n#{info.join("\n")}"
  end
end
