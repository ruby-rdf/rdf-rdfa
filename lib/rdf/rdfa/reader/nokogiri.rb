module RDF::RDFa
  class Reader < RDF::Reader
    ##
    # Nokogiri implementation of the RDFa reader.
    #
    # @see http://nokogiri.org/
    module Nokogiri
      ##
      # Returns the name of the underlying XML library.
      #
      # @return [Symbol]
      def self.library
        :nokogiri
      end

      # Proxy class to implement uniform element accessors
      class NodeProxy
        attr_reader :node

        def initialize(node)
          @node = node
        end

        ##
        # Element language
        #
        # From HTML5 [3.2.3.3]
        #   If both the lang attribute in no namespace and the lang attribute in the XML namespace are set
        #   on an element, user agents must use the lang attribute in the XML namespace, and the lang
        #   attribute in no namespace must be ignored for the purposes of determining the element's
        #   language.
        #
        # @return [String]
        def language
          language = case
          when @node.document.is_a?(::Nokogiri::HTML::Document) && @node.attributes["xml:lang"]
            @node.attributes["xml:lang"].to_s
          when @node.document.is_a?(::Nokogiri::HTML::Document) && @node.attributes["lang"]
            @node.attributes["lang"].to_s
          when @node.attribute_with_ns("lang", RDF::XML.to_s)
            @node.attribute_with_ns("lang", RDF::XML.to_s)
          when @node.attribute("lang")
            @node.attribute("lang").to_s
          end
        end

        ##
        # Return xml:base on element, if defined
        #
        # @return [String]
        def base
          @node.attribute_with_ns("base", RDF::XML.to_s)
        end

        def display_path
          @display_path ||= begin
            path = []
            path << @node.parent.display_path if @node.parent.respond_to?(:display_path)
            path << @node.display_path if @node.respond_to?(:display_path)
            case @node
            when ::Nokogiri::XML::Element then path.join("/")
            when ::Nokogiri::XML::Attr    then path.join("@")
            else path.join("?")
            end
          end
        end

        ##
        # Return true of all child elements are text
        #
        # @return [Array<:text, :element, :attribute>]
        def text_content?
          @node.children.all? {|c| c.text?}
        end

        ##
        # Retrieve an attribute value from a possibly namespaced attribute name
        #
        # @param [String] name
        # @return [String]
        #def attribute(name)
        #end
        #
        ###
        ## Retrieve a hash of attribute/value pairs for this element
        ##
        ## @return [Hash{Symbol => String}]
        #def attributes
        #end

        ##
        # Retrieve XMLNS definitions for this element
        #
        # @return [Hash{String => String}]
        def namespaces
          @node.namespace_definitions.inject({}) {|memo, ns| memo[ns.prefix] = ns.href.to_s; memo }
        end
        
        ##
        # Children of this node
        #
        # @return [NodeSetProxy]
        def children
          NodeSetProxy.new(@node.children)
        end

        ##
        # Proxy for everything else to @node
        def method_missing(method, *args)
          @node.send(method, *args)
        end
      end

      ##
      # NodeSet proxy
      class NodeSetProxy
        attr_reader :node_set

        def initialize(node_set)
          @node_set = node_set
        end

        ##
        # Return a proxy for each child
        #
        # @yield(child)
        # @yieldparam(NodeProxy)
        def each
          @node_set.each do |c|
            yield NodeProxy.new(c)
          end
        end

        ##
        # Proxy for everything else to @node_set
        def method_missing(method, *args)
          @node_set.send(method, *args)
        end
      end

      ##
      # Initializes the underlying XML library.
      #
      # @param  [Hash{Symbol => Object}] options
      # @return [void]
      def initialize_xml(input, options = {})
        require 'nokogiri' unless defined?(::Nokogiri)
        @doc = case input
        when ::Nokogiri::HTML::Document, ::Nokogiri::XML::Document
          input
        else
          # Try to detect charset from input
          options[:encoding] ||= input.charset if input.respond_to?(:charset)
          
          # Otherwise, default is utf-8
          options[:encoding] ||= 'utf-8'

          case @host_language
          when :html4, :html5
            if RUBY_PLATFORM == "java"
              ::Nokogiri::XML.parse(input, base_uri.to_s, options[:encoding])
            else
              ::Nokogiri::HTML.parse(input, base_uri.to_s, options[:encoding])
            end
          else
            ::Nokogiri::XML.parse(input, base_uri.to_s, options[:encoding])
          end
        end
      end

      # Determine the host language and/or version from options and the input document
      def detect_host_language_version(input, options)
        @host_language = options[:host_language] ? options[:host_language].to_sym : nil
        @version = options[:version] ? options[:version].to_sym : nil
        return if @host_language && @version

        # Snif version based on input
        case input
        when ::Nokogiri::XML::Document, ::Nokogiri::HTML::Document
          doc_type_string = input.doctype.to_s
          version_attr = input.root && input.root.attribute("version").to_s
          root_element = input.root.name.downcase
          root_namespace = input.root.namespace.to_s
          root_attrs = input.root.attributes
          content_type = case
          when root_element == "html" && input.is_a?(Nokogiri::HTML::Document)
            "text/html"
          when root_element == "html" && input.is_a?(Nokogiri::XML::Document)
            "application/xhtml+html"
          end
        else
          content_type = input.content_type if input.respond_to?(:content_type)

          # Determine from head of document
          head = if input.respond_to?(:read)
            input.rewind
            string = input.read(1000)
            input.rewind
            string.to_s
          else
            input.to_s[0..1000]
          end

          doc_type_string = head.match(%r(<!DOCTYPE[^>]*>)m).to_s
          root = head.match(%r(<[^!\?>]*>)m).to_s
          root_element = root.match(%r(^<(\S+)[ >])) ? $1 : ""
          version_attr = root.match(/version\s+=\s+(\S+)[\s">]/m) ? $1 : ""
          head_element = head.match(%r(<head.*<\/head>)mi)
          head_doc = ::Nokogiri::HTML.parse(head_element.to_s)

          # May determine content-type and/or charset from meta
          # Easist way is to parse head into a document and iterate
          # of CSS matches
          head_doc.css("meta").each do |e|
            if e.attr("http-equiv").to_s.downcase == 'content-type'
              content_type, e = e.attr("content").to_s.downcase.split(";")
              options[:encoding] = $1.downcase if e.to_s =~ /charset=([^\s]*)$/i
            elsif e.attr("charset")
              options[:encoding] = e.attr("charset").to_s.downcase
            end
          end
        end

        # Already using XML parser, determine from DOCTYPE and/or root element
        @version ||= :"rdfa1.0" if doc_type_string =~ /RDFa 1\.0/
        @version ||= :"rdfa1.0" if version_attr =~ /RDFa 1\.0/
        @version ||= :"rdfa1.1" if version_attr =~ /RDFa 1\.1/
        @version ||= :"rdfa1.1"

        @host_language ||= case content_type
        when "application/xml"  then :xml1
        when "image/svg+xml"    then :svg
        when "text/html"
          case doc_type_string
          when /html 4/i        then :html4
          when /xhtml/i         then :xhtml1
          when /html/i          then :html5
          end
        when "application/xhtml+xml"
          case doc_type_string
          when /html 4/i        then :html4
          when /xhtml/i         then :xhtml1
          when /html/i          then :xhtml5
          end
        else
          case root_element
          when /svg/i           then :svg
          when /html/i          then :html4
          end
        end

        @host_language ||= :xml1
      end

      # Accessor methods to mask native elements & attributes
      
      ##
      # Return proxy for document root
      def root
        @root ||= NodeProxy.new(@doc.root) if @doc
      end
      
      ##
      # Find value of document base
      #
      # @param [String] base Existing base from URI or :base_uri
      # @return [String]
      def doc_base(base)
        # find if the document has a base element
        case @host_language
        when :xhtml1, :xhtml5, :html4, :html5
          base_el = @doc.at_css("html>head>base") 
          base = base_el.attribute("href").to_s.split("#").first if base_el
        else
          xml_base = root.attribute_with_ns("base", RDF::XML.to_s)
          base = xml_base if xml_base
        end
        
        base
      end
    end
  end
end

module ::Nokogiri::XML
  ##
  # XML Exclusive Canonicalization (c14n) for Nokogiri.
  #
  # Classes mixin this module to implement canonicalization methods.
  #
  # This implementation acts in two parts, first to canonicalize the Node
  # or NoteSet in the context of its containing document, and second to
  # serialize to a lexical representation.
  #
  # @see # @see   http://www.w3.org/TR/xml-exc-c14n/
  class Node
    ##
    # Canonicalize the Node. Return a new instance of this node
    # which is canonicalized and marked as such
    #
    # @param [Hash{Symbol => Object}] options
    # @option options [Hash{String => String}] :namespaces
    #   Namespaces to apply to node.
    # @option options [#to_s] :language
    #   Language to set on node, unless an xml:lang is already set.
    def c14nxl(options = {})
      node = self.clone
      node.instance_variable_set(:@c14nxl, true)
      node
    end

    ##
    # Serialize a canonicalized Node or NodeSet to XML
    #
    # Override standard #to_s implementation to output in c14n representation
    # if the Node or NodeSet is marked as having been canonicalized
    def to_s_with_c14nxl
      if @c15nxl
        to_xml(:save_with => ::Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS)
      else
        to_s_without_c14nxl
      end
    end

    alias_method :to_s_without_c14nxl, :to_s
    alias_method :to_s, :to_s_with_c14nxl
  end

  class Element
    ##
    # Canonicalize the Element. Return a new instance of this node
    # which is canonicalized and marked as such.
    #
    # Apply namespaces either passed as an option, or that are in scope.
    #
    # @param [Hash{Symbol => Object}] options
    #   From {Nokogiri::XML::Node#c14nxl}
    def c14nxl(options = {})
      element = self.dup
      
      # Add in-scope namespace definitions
      options[:namespaces].each do |prefix, href|
        if prefix.to_s.empty?
          element.default_namespace = href unless element.namespace
        else
          element.add_namespace(prefix, href) unless element.namespaces[prefix]
        end
      end
      
      # Add language
      element["xml:lang"] = options[:language].to_s if
        options[:language] &&
        element.attribute_with_ns("lang", RDF::XML.to_s).to_s.empty? &&
        element.attribute("lang").to_s.empty?
      
      element
    end
  end
  
  class NodeSet
    ##
    # Canonicalize the NodeSet. Return a new NodeSet marked
    # as being canonical with all child nodes canonicalized.
    #
    # @param [Hash{Symbol => Object}] options
    #   Passed to {Nokogiri::XML::Node#c14nxl}
    def c14nxl(options = {})
      # Create a new NodeSet
      set = self.class.new(Nokogiri::XML::Document.new)
      set.instance_variable_set(:@c14nxl, true)
      
      # Unless passed a set of namespaces, figure them out from namespace_scopes
      #options[:namespaces] ||= first.parent.namespace_scopes.compact.inject({}) do |memo, ns|
      #  memo[ns.prefix] = ns.href.to_s
      #  memo
      #end

      self.each {|c| set << c.c14nxl(options)}
      set
    end

    ##
    # Serialize a canonicalized Node or NodeSet to XML
    #
    # Override standard #to_s implementation to output in c14n representation
    # if the Node or NodeSet is marked as having been canonicalized
    def to_s_with_c14nxl
      if @c15nxl
        to_xml(:save_with => ::Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS)
      else
        to_s_without_c14nxl
      end
    end

    alias_method :to_s_without_c14nxl, :to_s
    alias_method :to_s, :to_s_with_c14nxl
  end

  class Document
    def doctype
      self.children.first rescue false
    end
  end
  
end
