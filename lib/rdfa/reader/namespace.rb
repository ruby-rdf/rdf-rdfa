module RDF::RDFa class Reader
  # From RdfContext
  class Namespace
    attr_accessor :prefix, :fragment
 
    # Creates a new namespace given a URI and the prefix.
    def initialize(uri, prefix)
      prefix = prefix.to_s

      @uri = uri.to_s

      raise ParserException, "Invalid prefix '#{prefix}'" unless prefix_valid?(prefix)
      @prefix = prefix
    end

    # Allows the construction of arbitrary URIs on the namespace.
    def method_missing(methodname, *args)
      self + methodname
    end

    # Construct a URIRef from a namespace as in method_missing, but without method collision issues.
    # Rules are somewhat different than for normal URI unions, as the raw URI is used as the source,
    # not a normalized URI, and the result is not normalized
    def +(suffix)
      prefix = @uri
      suffix = suffix.to_s.sub(/^\#/, "") if prefix.index("#")
      suffix = suffix.to_s.sub(/_$/, '')
      # FIXME: URIRef.new(prefix + suffix.to_s, :normalize => false, :namespace => self)
      RDF::URI.new(prefix + suffix.to_s)
    end

    # Make sure to attach fragment
    def uri
      self + ""
    end
    
    # Bind this namespace to a Graph
    def bind(graph)
      graph.bind(self)
    end

    # Compare namespaces
    def eql?(other)
      self.uri == other.uri
    end
    alias_method :==, :eql?

    # Output xmlns attribute name
    def xmlns_attr
      prefix.empty? ? "xmlns" : "xmlns:#{prefix}"
    end
    
    # Output namespace definition as a hash
    def xmlns_hash
      {xmlns_attr => @uri.to_s}
    end
    
    def to_s
      "#{prefix}: #{@uri}"
    end
    
    def inspect
      "Namespace[abbr='#{prefix}',uri='#{@uri}']"
    end
    
    private
    # The Namespace prefix must be an NCName
    def prefix_valid?(prefix)
      NC_REGEXP.match(prefix.to_s) || prefix.to_s.empty?
    end
  end
end end
