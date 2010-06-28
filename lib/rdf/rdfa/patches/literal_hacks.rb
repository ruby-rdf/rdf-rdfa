# Use Nokogiri or LibXML when available, and REXML otherwise:
begin
  require 'nokogiri'
rescue LoadError => e
  begin
    require 'libxml'
  rescue LoadError => e
    :rexml
  end
end

module RDF; class Literal
  ##
  # An XML literal.
  #
  # @see   http://www.w3.org/TR/rdf-concepts/#section-XMLLiteral
  # @see   http://www.w3.org/TR/rdfa-core/#s_xml_literals
  # @since 0.2.1
  class XML < Literal
    DATATYPE = RDF.XMLLiteral
    GRAMMAR  = nil

    ##
    # @param  [Object] value
    # @option options [String] :lexical (nil)
    # @option options [Hash] :namespaces (nil)
    # @option options [Hash] :namespaces ({})
    # @option options [Symbol] :language (nil)
    # @option options [Symbol] :library (:nokogiri, :libxml, or :rexml)
    def initialize(value, options = {})
      options[:namespaces] ||= {}

      @library = case options[:library]
        when nil
          case
          when defined?(::Nokogiri) then :nokogiri
          when defined?(::LibXML)   then :libxml
          else                           :rexml
          end
        when :nokogiri, :libxml, :rexml
          options[:library]
        else
          raise ArgumentError.new("expected :rexml, :libxml or :nokogiri, but got #{options[:library].inspect}")
      end

      @datatype = options[:datatype] || DATATYPE
      @string   = options[:lexical] if options.has_key?(:lexical)
      @object   = parse_value(value, options)
      @string   = serialize_nodeset(@object)
    end

    ##
    # Converts the literal into its canonical lexical representation.
    #
    # @return [Literal]
    # @see    http://www.w3.org/TR/xml-exc-c14n/
    def canonicalize
      # This is the opportunity to use exclusive canonicalization library
      self
    end

    ##
    # Returns the value as a string.
    #
    # @return [String]
    def to_s
      @string
    end
    
    private
    
    def parse_value(value, options)
      ns_hash = {}
      options[:namespaces].each_pair do |prefix, uri|
        attr = prefix.to_s.empty? ? "xmlns" : "xmlns:#{prefix}"
        ns_hash[attr] = uri.to_s
      end
      ns_strs = []
      ns_hash.each_pair {|a, u| ns_strs << "#{a}=\"#{u}\""}

      case @library
      when :nokogiri  then parse_value_nokogiri(value, ns_strs, options[:language])
      when :libxml    then parse_value_libxml(value, ns_strs, options[:language])
      when :rexml     then parse_value_rexml(value, ns_strs, options[:language])
      else                 value.to_s
      end
    end
    
    def serialize_nodeset(object)
      case @library
      when :nokogiri  then serialize_nodeset_nokogiri(object)
      when :libxml    then serialize_nodeset_libxml(object)
      when :rexml     then serialize_nodeset_rexml(object)
      else                 object
      end
    end
    
    # Nokogiri implementations
    if defined?(::Nokogiri)
      def parse_value_nokogiri(value, ns_strs, language)
        return value if value.is_a?(Nokogiri::XML::NodeSet)
        # Add inherited namespaces to created root element so that they're inherited to sub-elements
        elements = Nokogiri::XML::Document.parse("<foo #{ns_strs.join(" ")}>#{value.to_s}</foo>").root.children

        elements.map do |c|
          if c.is_a?(Nokogiri::XML::Element)
            c = Nokogiri::XML.parse(c.dup.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS)).root
            # Gather namespaces from self and decendant nodes
            c.traverse do |n|
              ns = n.namespace
              next unless ns
              prefix = ns.prefix ? "xmlns:#{ns.prefix}" : "xmlns"
              c[prefix] = ns.href.to_s unless c.namespaces[prefix]
            end

            # Add lanuage
            if language && c["lang"].to_s.empty?
              c["xml:lang"] = language
            end
          end
          c
        end
      end
    
      def serialize_nodeset_nokogiri(object)
        object.map {|c| c.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS)}.join("")
      end
    end   # Nokogiri
    
    if defined?(::LibXML)
      def parse_value_libxml(value, ns_strs, language)
        # Fixme
      end

      def serialize_nodeset_libxml(object)
        # Fixme
      end
    end   # LibXML
    
    # REXML
    def parse_value_rexml(value, ns_strs, language)
      # Fixme
    end

    def serialize_nodeset_rexml(object)
      # Fixme
    end
    
  end # class XML
end; end