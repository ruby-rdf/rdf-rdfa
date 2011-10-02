# Use Nokogiri when available, and REXML otherwise:
begin
  require 'nokogiri'
rescue LoadError => e
  require 'rexml/document'
end

module RDF; class Literal
  ##
  # An XML literal.
  #
  # XML Literals are maintained in a lexical form, unless an object form is provided.
  # The both lexical and object forms are presumed to be in Exclusive Canonical XML.
  # As generating this form is dependent on the context of the XML Literal from the
  # original document, canonicalization cannot be performed directly within this
  # class.
  #
  # @see   http://www.w3.org/TR/rdf-concepts/#section-XMLLiteral
  # @see   http://www.w3.org/TR/rdfa-core/#s_xml_literals
  # @see   http://www.w3.org/TR/xml-exc-c14n/
  # @since 0.2.1
  class XML < Literal
    ##
    # @param  [Object] value
    # @option options [String] :lexical (nil)
    # @option options [:nokogiri, :rexml] :library
    #   Library to use, defaults to :nokogiri if available, :rexml otherwise
    def initialize(value, options = {})
      @datatype = options[:datatype] || DATATYPE
      @string   = options[:lexical] if options.has_key?(:lexical)
      if value.is_a?(String)
        @string ||= value
      else
        @object = value
      end

      @library = options[:library] ||
        case
        when defined?(::Nokogiri) then :nokogiri
        else                           :rexml
        end
    end

    ##
    # Parse value, if necessary
    #
    # @return [Object]
    def object
      @object ||= case @library
      when :nokogiri  then parse_nokogiri(value)
      when :rexml     then parse_rexml(value)
      end
    end

    def to_s
      @string ||= @object.to_s
    end

    ##
    # XML Equivalence. XML Literals can be compared with each other or with xsd:strings
    #
    # @param [Object] other
    # @return [Boolean] `true` or `false`
    #
    # @see http://www.w3.org/TR/rdf-concepts/#section-XMLLiteral
    def eql?(other)
      if other.is_a?(Literal::XML)
        case @library
        when :nokogiri  then equivalent_nokogiri(other)
        when :rexml     then equivalent_rexml(other)
        end
      elsif other.is_a?(Literal) && (other.plain? || other.datatype == RDF::XSD.string)
        value == other.value
      else
        super
      end
    end

    private
    
    # Nokogiri implementations
    if defined?(::Nokogiri)
      ##
      # Parse the value either as a NodeSet, as results are equivalent if it is just a node
      def parse_nokogiri(value)
        Nokogiri::XML.parse("<root>#{value}</root>").root.children
      end

      # Use equivalent-xml to determine equivalence
      def equivalent_nokogiri(other)
        require 'equivalent-xml'
        res = EquivalentXml.equivalent?(object, other.object)
        res
      end
    end
    
    ##
    # Parse the value either as a NodeSet, as results are equivalent if it is just a node
    def parse_rexml(value)
      REXML::Document.new("<root>#{value}</root>").root.children
    end
    

    # Simple equivalence test for REXML
    def equivalent_rexml(other)
      begin
        require 'active_support/core_ext'
      rescue LoadError => e
        # string equivalence
      end

      if Hash.respond_to?(:from_xml)
        Hash.from_xml(value) == Hash.from_xml(other.value)
      else
        # Poor mans equivalent
        value == other.value
      end
    end
  end # class XML
end; end