require 'rspec/matchers'

RSpec::Matchers.define :have_xpath do |path, value, logger|
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
    msg +=  "\nDebug:#{logger}"
    msg
  end

  failure_message_when_negated do |actual|
    msg = "expected that #{path.inspect}\nwould not be #{value.inspect}"
    msg += "\nsource:" + actual
    msg +=  "\nDebug:#{logger}"
    msg
  end
end

Info = Struct.new(:id, :logger, :compare, :inputDocument, :outputDocument, :expectedResults, :format, :title)

RSpec::Matchers.define :pass_query do |expected, info|
  match do |actual|
    if info.respond_to?(:id)
      @info = info
    elsif info.is_a?(Logger)
      Info.new("", info)
    elsif info.is_a?(Hash)
      @info =  Info.new(info[:id], info[:logger], info[:compare])
      @info[:expectedResults] = info[:expectedResults] || RDF::Literal::Boolean.new(true)
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
    trace = case @info.logger
    when Logger then @info.logger.to_s
    when Array then @info.logger.join("\n")
    end
    "#{@info.inspect + "\n"}" +
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
    "\nDebug:\n#{trace}"
  end

  failure_message_when_negated do |actual|
    trace = case @info.logger
    when Logger then @info.logger.to_s
    when Array then @info.logger.join("\n")
    end
    "#{@info.inspect + "\n"}" +
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
    "\nDebug:\n#{trace}"
  end
end
