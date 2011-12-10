begin
  raise LoadError, "not with java" if RUBY_PLATFORM == "java"
  require 'nokogiri'
rescue LoadError => e
  :rexml
end
require 'rdf/ntriples'
require 'rdf/xsd'

module RDF::RDFa
  ##
  # An RDFa parser in Ruby
  #
  # This class supports [Nokogiri][] for HTML
  # processing, and will automatically select the most performant
  # implementation (Nokogiri or LibXML) that is available. If need be, you
  # can explicitly override the used implementation by passing in a
  # `:library` option to `Reader.new` or `Reader.open`.
  #
  # [Nokogiri]: http://nokogiri.org/
  #
  # Based on processing rules described here:
  # @see http://www.w3.org/TR/rdfa-syntax/#s_model RDFa 1.0
  # @see http://www.w3.org/TR/2011/WD-rdfa-core-20110331/ RDFa Core 1.1
  # @see http://www.w3.org/TR/2011/WD-xhtml-rdfa-20110331/ XHTML+RDFa 1.1
  #
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  class Reader < RDF::Reader
    format Format
    include Expansion

    XHTML = "http://www.w3.org/1999/xhtml"
    
    SafeCURIEorCURIEorURI = {
      :"rdfa1.0" => [:term, :safe_curie, :uri, :bnode],
      :"rdfa1.1" => [:safe_curie, :curie, :term, :uri, :bnode],
    }
    TERMorCURIEorAbsURI = {
      :"rdfa1.0" => [:term, :curie],
      :"rdfa1.1" => [:term, :curie, :absuri],
    }
    TERMorCURIEorAbsURIprop = {
      :"rdfa1.0" => [:curie],
      :"rdfa1.1" => [:term, :curie, :absuri],
    }

    # This expression matches an NCName as defined in
    # [XML-NAMES](http://www.w3.org/TR/2009/REC-xml-names-20091208/#NT-NCName)
    #
    # @see http://www.w3.org/TR/2009/REC-xml-names-20091208/#NT-NCName
    NC_REGEXP = Regexp.new(
      %{^
        (?!\\\\u0301)             # &#x301; is a non-spacing acute accent.
                                  # It is legal within an XML Name, but not as the first character.
        (  [a-zA-Z_]
         | \\\\u[0-9a-fA-F]{4}
        )
        (  [0-9a-zA-Z_\.-/]
         | \\\\u([0-9a-fA-F]{4})
        )*
      $},
      Regexp::EXTENDED)

    # This expression matches an term as defined in
    # [RDFA-CORE](http://www.w3.org/TR/2011/WD-rdfa-core-20111215/#s_terms)
    #
    # @see http://www.w3.org/TR/2011/WD-rdfa-core-20111215/#s_terms
    TERM_REGEXP = Regexp.new(
      %{^
        (?!\\\\u0301)             # &#x301; is a non-spacing acute accent.
                                  # It is legal within an XML Name, but not as the first character.
        (  [a-zA-Z_]
         | \\\\u[0-9a-fA-F]{4}
        )
        (  [0-9a-zA-Z_\.-]
         | \\\\u([0-9a-fA-F]{4})
        )*
      $},
      Regexp::EXTENDED)

    # Host language
    # @attr [:xml1, :xhtml1, :xhtml5, :html4, :html5, :svg]
    attr_reader :host_language
    
    # Version
    # @attr [:"rdfa1.0", :"rdfa1.1"]
    attr_reader :version
    
    # The Recursive Baggage
    # @private
    class EvaluationContext # :nodoc:
      ##
      # The base.
      #
      # This will usually be the URL of the document being processed,
      # but it could be some other URL, set by some other mechanism,
      # such as the (X)HTML base element. The important thing is that it establishes
      # a URL against which relative paths can be resolved.
      #
      # @attr [RDF::URI]
      attr :base, true

      ##
      # The parent subject.
      #
      # The initial value will be the same as the initial value of base,
      # but it will usually change during the course of processing.
      #
      # @attr [RDF::URI]
      attr :parent_subject, true
      
      ##
      # The parent object.
      #
      # In some situations the object of a statement becomes the subject of any nested statements,
      # and this property is used to convey this value.
      # Note that this value may be a bnode, since in some situations a number of nested statements
      # are grouped together on one bnode.
      # This means that the bnode must be set in the containing statement and passed down,
      # and this property is used to convey this value.
      #
      # @attr [RDF::URI]
      attr :parent_object, true
      
      ##
      # A list of current, in-scope URI mappings.
      #
      # @attr [Hash{Symbol => String}]
      attr :uri_mappings, true
      
      ##
      # A list of current, in-scope Namespaces. This is the subset of uri_mappings
      # which are defined using xmlns.
      #
      # @attr [Hash{String => Namespace}]
      attr :namespaces, true
      
      ##
      # A list of incomplete triples.
      #
      # A triple can be incomplete when no object resource
      # is provided alongside a predicate that requires a resource (i.e., @rel or @rev).
      # The triples can be completed when a resource becomes available,
      # which will be when the next subject is specified (part of the process called chaining).
      #
      # @attr [Array<Array<RDF::URI, RDF::Resource>>]
      attr :incomplete_triples, true
      
      ##
      # The language. Note that there is no default language.
      #
      # @attr [Symbol]
      attr :language, true
      
      ##
      # The term mappings, a list of terms and their associated URIs.
      #
      # This specification does not define an initial list.
      # Host Languages may define an initial list.
      # If a Host Language provides an initial list, it should do so via an RDFa Profile document.
      #
      # @attr [Hash{Symbol => RDF::URI}]
      attr :term_mappings, true
      
      ##
      # The default vocabulary
      #
      # A value to use as the prefix URI when a term is used.
      # This specification does not define an initial setting for the default vocabulary.
      # Host Languages may define an initial setting.
      #
      # @attr [RDF::URI]
      attr :default_vocabulary, true

      ##
      # lists
      #
      # A hash associating lists with properties.
      # @attr [Hash{RDF::URI => Array<RDF::Resource>}]
      attr :list_mapping, true

      # @param [RDF::URI] base
      # @param [Hash] host_defaults
      # @option host_defaults [Hash{String => RDF::URI}] :term_mappings Hash of NCName => URI
      # @option host_defaults [Hash{String => RDF::URI}] :vocabulary Hash of prefix => URI
      def initialize(base, host_defaults)
        # Initialize the evaluation context, [5.1]
        @base = base
        @parent_subject = @base
        @parent_object = nil
        @namespaces = {}
        @incomplete_triples = []
        @language = nil
        @uri_mappings = host_defaults.fetch(:uri_mappings, {})
        @term_mappings = host_defaults.fetch(:term_mappings, {})
        @default_vocabulary = host_defaults.fetch(:vocabulary, nil)
      end

      # Copy this Evaluation Context
      #
      # @param [EvaluationContext] from
      def initialize_copy(from)
        # clone the evaluation context correctly
        @uri_mappings = from.uri_mappings.clone
        @incomplete_triples = from.incomplete_triples.clone
        @namespaces = from.namespaces.clone
        @list_mapping = from.list_mapping # Don't clone
      end
      
      def inspect
        v = ['base', 'parent_subject', 'parent_object', 'language', 'default_vocabulary'].map do |a|
          "#{a}=#{self.send(a).inspect}"
        end
        v << "uri_mappings[#{uri_mappings.keys.length}]"
        v << "incomplete_triples[#{incomplete_triples.length}]"
        v << "term_mappings[#{term_mappings.keys.length}]"
        v << "lists[#{list_mapping.keys.length}]" if list_mapping
        v.join(", ")
      end
    end

    # Returns the XML implementation module for this reader instance.
    #
    # @attr_reader [Module]
    attr_reader :implementation

    ##
    # Initializes the RDFa reader instance.
    #
    # @param  [IO, File, String] input
    #   the input stream to read
    # @param  [Hash{Symbol => Object}] options
    #   any additional options (see `RDF::Reader#initialize`)
    # @option options [Symbol] :library
    #   One of :nokogiri or :rexml. If nil/unspecified uses :nokogiri if available, :rexml otherwise.
    # @option options [Boolean]  :expand (false)
    #   whether to perform RDFS expansion on the resulting graph
    # @option options [:xml1, :xhtml1, :xhtml5, :html4, :html5, :svg] :host_language (:xhtml1)
    #   Host Language
    # @option options [:"rdfa1.0", :"rdfa1.1"] :version (:"rdfa1.1")
    #   Parser version information
    # @option options [RDF::Writable]    :processor_graph (nil)
    #   Graph to record information, warnings and errors.
    # @option options [Repository] :vocab_repository (nil)
    #   Repository to save loaded vocabularies.
    # @option options [Array] :debug
    #   Array to place debug messages
    # @return [reader]
    # @yield  [reader] `self`
    # @yieldparam  [RDF::Reader] reader
    # @yieldreturn [void] ignored
    # @raise [Error]:: Raises RDF::ReaderError if _validate_
    def initialize(input = $stdin, options = {}, &block)
      super do
        @debug = options[:debug]

        @processor_graph = options[:processor_graph]

        @library = case options[:library]
          when nil
            # Use Nokogiri when available, and REXML otherwise:
            (defined?(::Nokogiri) && RUBY_PLATFORM != 'java') ? :nokogiri : :rexml
          when :nokogiri, :rexml
            options[:library]
          else
            raise ArgumentError.new("expected :rexml or :nokogiri, but got #{options[:library].inspect}")
        end

        require "rdf/rdfa/reader/#{@library}"
        @implementation = case @library
          when :nokogiri then Nokogiri
          when :rexml    then REXML
        end
        self.extend(@implementation)

        detect_host_language_version(input, options)

        add_info(@doc, "version = #{@version},  host_language = #{@host_language}, library = #{@library}")

        initialize_xml(input, options) rescue raise RDF::ReaderError.new($!.message)

        if (root.nil? && validate?)
          add_error(nil, "Empty document", RDF::RDFA.DocumentError)
          raise RDF::ReaderError, "Empty Document"
        end
        add_warning(nil, "Syntax errors:\n#{doc_errors}", RDF::RDFA.DocumentError) if !doc_errors.empty? && validate?

        # Section 4.2 RDFa Host Language Conformance
        #
        # The Host Language may require the automatic inclusion of one or more Initial Contexts
        @host_defaults = {
          :vocabulary       => nil,
          :uri_mappings     => {},
          :initial_contexts => [],
        }

        if @version == :"rdfa1.0"
          # Add default term mappings
          @host_defaults[:term_mappings] = %w(
            alternate appendix bookmark cite chapter contents copyright first glossary help icon index
            last license meta next p3pv1 prev role section stylesheet subsection start top up
            ).inject({}) { |hash, term| hash[term] = RDF::XHV[term]; hash }
        end

        case @host_language
        when :xml1, :svg
          @host_defaults[:initial_contexts] = [XML_RDFA_CONTEXT]
        when :xhtml1
          @host_defaults[:initial_contexts] = [XML_RDFA_CONTEXT, XHTML_RDFA_CONTEXT]
        when :xhtml5, :html4, :html5
          @host_defaults[:initial_contexts] = [XML_RDFA_CONTEXT, HTML_RDFA_CONTEXT]
        end

        block.call(self) if block_given?
      end
    end

    ##
    # Iterates the given block for each RDF statement in the input.
    #
    # Reads to graph and performs expansion if required.
    #
    # @yield  [statement]
    # @yieldparam [RDF::Statement] statement
    # @return [void]
    def each_statement(&block)
      if @options[:expand]
        @options[:expand] = false
        expand.each_statement(&block)
        @options[:expand] = true
      else
        @callback = block

        # Add prefix definitions from host defaults
        @host_defaults[:uri_mappings].each_pair do |prefix, value|
          prefix(prefix, value)
        end

        # parse
        parse_whole_document(@doc, RDF::URI(base_uri))
      end
    end

    ##
    # Iterates the given block for each RDF triple in the input.
    #
    # @yield  [subject, predicate, object]
    # @yieldparam [RDF::Resource] subject
    # @yieldparam [RDF::URI]      predicate
    # @yieldparam [RDF::Value]    object
    # @return [void]
    def each_triple(&block)
      each_statement do |statement|
        block.call(*statement.to_triple)
      end
    end
    
    private

    # Keep track of allocated BNodes
    def bnode(value = nil)
      @bnode_cache ||= {}
      @bnode_cache[value.to_s] ||= RDF::Node.new(value)
    end
    
    # Figure out the document path, if it is an Element or Attribute
    def node_path(node)
      "<#{base_uri}>#{node.respond_to?(:display_path) ? node.display_path : node}"
    end
    
    # Add debug event to debug array, if specified
    #
    # @param [#display_path, #to_s] node:: XML Node or string for showing context
    # @param [String] message::
    # @yieldreturn [String] appended to message, to allow for lazy-evaulation of message
    def add_debug(node, message = "")
      return unless ::RDF::RDFa.debug? || @debug
      message = message + yield if block_given?
      add_processor_message(node, message, RDF::RDFA.Info)
    end

    def add_info(node, message, process_class = RDF::RDFA.Info)
      add_processor_message(node, message, process_class)
    end
    
    def add_warning(node, message, process_class = RDF::RDFA.Warning)
      add_processor_message(node, message, process_class)
    end
    
    def add_error(node, message, process_class = RDF::RDFA.Error)
      add_processor_message(node, message, process_class)
      raise RDF::ReaderError, message if validate?
    end
    
    def add_processor_message(node, message, process_class)
      puts "#{node_path(node)}: #{message}" if ::RDF::RDFa.debug?
      @debug << "#{node_path(node)}: #{message}" if @debug.is_a?(Array)
      if @processor_graph
        n = RDF::Node.new
        @processor_graph << RDF::Statement.new(n, RDF["type"], process_class)
        @processor_graph << RDF::Statement.new(n, RDF::DC.description, message)
        @processor_graph << RDF::Statement.new(n, RDF::DC.date, RDF::Literal::Date.new(DateTime.now))
        @processor_graph << RDF::Statement.new(n, RDF::RDFA.context, base_uri)
        nc = RDF::Node.new
        @processor_graph << RDF::Statement.new(nc, RDF["type"], RDF::PTR.XPathPointer)
        @processor_graph << RDF::Statement.new(nc, RDF::PTR.expression, node.path) if node.respond_to?(:path)
        @processor_graph << RDF::Statement.new(n, RDF::RDFA.context, nc)
      end
    end

    # add a statement, object can be literal or URI or bnode
    #
    # @param [#display_path, #to_s] node:: XML Node or string for showing context
    # @param [RDF::URI, RDF::BNode] subject:: the subject of the statement
    # @param [RDF::URI] predicate:: the predicate of the statement
    # @param [URI, RDF::BNode, RDF::Literal] object:: the object of the statement
    # @return [RDF::Statement]:: Added statement
    # @raise [RDF::ReaderError]:: Checks parameter types and raises if they are incorrect if parsing mode is _validate_.
    def add_triple(node, subject, predicate, object)
      statement = RDF::Statement.new(subject, predicate, object)
      add_info(node, "statement: #{RDF::NTriples.serialize(statement)}")
      @callback.call(statement)
    end

    # Parsing an RDFa document (this is *not* the recursive method)
    def parse_whole_document(doc, base)
      base = doc_base(base)
      if (base)
        # Strip any fragment from base
        base = base.to_s.split("#").first
        base = uri(base)
        add_debug("") {"parse_whole_doc: base='#{base}'"}
      end

      # initialize the evaluation context with the appropriate base
      evaluation_context = EvaluationContext.new(base, @host_defaults)
      
      if @version != :"rdfa1.0"
        # Process default vocabularies
        load_initial_contexts(@host_defaults[:initial_contexts]) do |which, value|
          add_debug(root) { "parse_whole_document, #{which}: #{value.inspect}"}
          case which
          when :uri_mappings        then evaluation_context.uri_mappings.merge!(value)
          when :term_mappings       then evaluation_context.term_mappings.merge!(value)
          when :default_vocabulary  then evaluation_context.default_vocabulary = value
          end
        end
      end
      
      traverse(root, evaluation_context)
      add_debug("", "parse_whole_doc: traversal complete'")
    end
  
    # Parse and process URI mappings, Term mappings and a default vocabulary from @profile
    #
    # Yields each mapping
    def load_initial_contexts(initial_contexts)
      initial_contexts.
        map {|uri| uri(uri).normalize}.
        each do |uri|
          # Don't try to open ourselves!
          if base_uri == uri
            add_debug(root) {"load_initial_contexts: skip recursive profile <#{uri}>"}
            next
          end

          old_debug = RDF::RDFa.debug?
          begin
            add_info(root, "load_initial_contexts: load <#{uri}>")
            RDF::RDFa.debug = false
            profile = Profile.find(uri)
          rescue Exception => e
            RDF::RDFa.debug = old_debug
            add_error(root, e.message, RDF::RDFA.ProfileReferenceError)
            raise # In case we're not in strict mode, we need to be sure processing stops
          ensure
            RDF::RDFa.debug = old_debug
          end

          # Add URI Mappings to prefixes
          profile.prefixes.each_pair do |prefix, value|
            prefix(prefix, value)
          end
          yield :uri_mappings, profile.prefixes unless profile.prefixes.empty?
          yield :term_mappings, profile.terms unless profile.terms.empty?
          yield :default_vocabulary, profile.vocabulary if profile.vocabulary
        end
    end

    # Extract the XMLNS mappings from an element
    def extract_mappings(element, uri_mappings, namespaces)
      # look for xmlns
      # (note, this may be dependent on @host_language)
      # Regardless of how the mapping is declared, the value to be mapped must be converted to lower case,
      # and the URI is not processed in any way; in particular if it is a relative path it is
      # not resolved against the current base.
      ns_defs = {}
      element.namespaces.each do |prefix, href|
        prefix = nil if prefix == "xmlns"
        add_debug("extract_mappings") { "ns: #{prefix}: #{href}"}
        ns_defs[prefix] = href
      end

      # HTML parsing doesn't create namespace_definitions
      if ns_defs.empty?
        ns_defs = {}
        element.attributes.each do |attr, href|
          next unless attr =~ /^xmlns(?:\:(.+))?/
          prefix = $1
          add_debug("extract_mappings") { "ns(attr): #{prefix}: #{href}"}
          ns_defs[prefix] = href.to_s
        end
      end

      ns_defs.each do |prefix, href|
        # A Conforming RDFa Processor must ignore any definition of a mapping for the '_' prefix.
        next if prefix == "_"

        # Downcase prefix for RDFa 1.1
        pfx_lc = (@version == :"rdfa1.0" || prefix.nil?) ? prefix : prefix.downcase
        if prefix
          uri_mappings[pfx_lc.to_sym] = href
          namespaces[pfx_lc] ||= href
          prefix(pfx_lc, href)
          add_info(element, "extract_mappings: #{prefix} => <#{href}>")
        else
          add_info(element, "extract_mappings: nil => <#{href}>")
          namespaces[""] ||= href
        end
      end

      # Set mappings from @prefix
      # prefix is a whitespace separated list of prefix-name URI pairs of the form
      #   NCName ':' ' '+ xs:anyURI
      mappings = element.attribute("prefix").to_s.strip.split(/\s+/)
      while mappings.length > 0 do
        prefix, uri = mappings.shift.downcase, mappings.shift
        #puts "uri_mappings prefix #{prefix} <#{uri}>"
        next unless prefix.match(/:$/)
        prefix.chop!
        
        unless prefix.match(NC_REGEXP)
          add_error(element, "extract_mappings: Prefix #{prefix.inspect} does not match NCName production")
          next
        end

        # A Conforming RDFa Processor must ignore any definition of a mapping for the '_' prefix.
        next if prefix == "_"

        uri_mappings[prefix.to_s.empty? ? nil : prefix.to_s.to_sym] = uri
        prefix(prefix, uri)
        add_info(element, "extract_mappings: prefix #{prefix} => <#{uri}>")
      end unless @version == :"rdfa1.0"
    end

    # The recursive helper function
    def traverse(element, evaluation_context)
      if element.nil?
        add_error(element, "Can't parse nil element")
        return nil
      end
      
      add_debug(element) { "ec: #{evaluation_context.inspect}" }

      # local variables [7.5 Step 1]
      recurse = true
      skip = false
      new_subject = nil
      typed_resource = nil
      current_object_resource = nil
      uri_mappings = evaluation_context.uri_mappings.clone
      namespaces = evaluation_context.namespaces.clone
      incomplete_triples = []
      language = evaluation_context.language
      term_mappings = evaluation_context.term_mappings.clone
      default_vocabulary = evaluation_context.default_vocabulary
      list_mapping = evaluation_context.list_mapping

      xml_base = element.base
      base = xml_base.to_s if xml_base && ![:xhtml1, :xhtml5, :html4, :html5].include?(@host_language)
      base ||= evaluation_context.base

      # Pull out the attributes needed for the skip test.
      attrs = {}
      %w(
        about
        content
        data
        datatype
        datetime
        href
        inlist
        property
        rel
        resource
        rev
        src
        typeof
        value
        vocab
      ).each do |a|
        attrs[a.to_sym] = element.attributes[a].to_s.strip if element.attributes[a]
      end

      add_debug(element) {"attrs " + attrs.inspect} unless attrs.empty?

      # Default vocabulary [7.5 Step 2]
      # Next the current element is examined for any change to the default vocabulary via @vocab.
      # If @vocab is present and contains a value, its value updates the local default vocabulary.
      # If the value is empty, then the local default vocabulary must be reset to the Host Language defined default.
      if attrs[:vocab]
        default_vocabulary = if attrs[:vocab].empty?
          # Set default_vocabulary to host language default
          add_debug(element) {
            "[Step 3] reset default_vocaulary to #{@host_defaults.fetch(:vocabulary, nil).inspect}"
          }
          @host_defaults.fetch(:vocabulary, nil)
        else
          # Generate a triple indicating that the vocabulary is used
          add_triple(element, base, RDF::RDFA.hasVocabulary, uri(attrs[:vocab]))

          uri(attrs[:vocab])
        end
        add_debug(element) {
          "[Step 2] default_vocaulary: #{default_vocabulary.inspect}"
        }
      end
      
      # Local term mappings [7.5 Step 3]
      # Next, the current element is then examined for URI mapping s and these are added to the local list of URI mappings.
      # Note that a URI mapping will simply overwrite any current mapping in the list that has the same name
      extract_mappings(element, uri_mappings, namespaces)
    
      # Language information [7.5 Step 4]
      language = element.language || language
      language = nil if language.to_s.empty?
      add_debug(element) {"HTML5 [3.2.3.3] lang: #{language.inspect}"} if language
    
      # rels and revs
      rels = process_uris(element, attrs[:rel], evaluation_context, base,
                          :uri_mappings => uri_mappings,
                          :term_mappings => term_mappings,
                          :vocab => default_vocabulary,
                          :restrictions => TERMorCURIEorAbsURI.fetch(@version, []))
      revs = process_uris(element, attrs[:rev], evaluation_context, base,
                          :uri_mappings => uri_mappings,
                          :term_mappings => term_mappings,
                          :vocab => default_vocabulary,
                          :restrictions => TERMorCURIEorAbsURI.fetch(@version, []))
    
      add_debug(element) do
        "rels: #{rels.join(" ")}, revs: #{revs.join(" ")}"
      end unless (rels + revs).empty?

      if !(attrs[:rel] || attrs[:rev])
        # Establishing a new subject if no rel/rev [7.5 Step 5]
        
        if @version == :"rdfa1.0"
          new_subject = if attrs[:about]
            process_uri(element, attrs[:about], evaluation_context, base,
                        :uri_mappings => uri_mappings,
                        :restrictions => SafeCURIEorCURIEorURI.fetch(@version, []))
          elsif attrs[:resource]
            process_uri(element, attrs[:resource], evaluation_context, base,
                        :uri_mappings => uri_mappings,
                        :restrictions => SafeCURIEorCURIEorURI.fetch(@version, []))
          elsif attrs[:href] || attrs[:src]
            process_uri(element, (attrs[:href] || attrs[:src]), evaluation_context, base, :restrictions => [:uri])
          end

          # If no URI is provided by a resource attribute, then the first match from the following rules
          # will apply:
          new_subject ||= if [:xhtml1, :xhtml5, :html4, :html5].include?(@host_language) && element.name =~ /^(head|body)$/
            # From XHTML+RDFa 1.1:
            # if no URI is provided, then first check to see if the element is the head or body element.
            # If it is, then act as if there is an empty @about present, and process it according to the rule for @about.
            uri(base)
          elsif element == root && base
            # if the element is the root element of the document, then act as if there is an empty @about present,
            # and process it according to the rule for @about, above;
            uri(base)
          elsif attrs[:typeof]
            RDF::Node.new
          else
            # otherwise, if parent object is present, new subject is set to the value of parent object.
            skip = true unless attrs[:property]
            evaluation_context.parent_object
          end

          # if the @typeof attribute is present, set typed resource to new subject
          typed_resource = new_subject if attrs[:typeof]
        else
          # If the current element contains the @property attribute, but does not contain the @content or the @datatype attribute
          if attrs[:property] && !(attrs[:content] || attrs[:datatype]) && evaluation_context.incomplete_triples.empty?
            new_subject = process_uri(element, attrs[:about], evaluation_context, base,
                        :uri_mappings => uri_mappings,
                        :restrictions => SafeCURIEorCURIEorURI.fetch(@version, [])) if attrs[:about]

            # if the @typeof attribute is present, set typed resource to new subject
            typed_resource = new_subject if attrs[:typeof]

            # If no URI is provided by a resource attribute, then the first match from the following rules
            # will apply:
            new_subject ||= if [:xhtml1, :xhtml5, :html4, :html5].include?(@host_language) && element.name =~ /^(head|body)$/
              # From XHTML+RDFa 1.1:
              # if no URI is provided, then first check to see if the element is the head or body element.
              # If it is, then act as if there is an empty @about present, and process it according to the rule for @about.
              uri(base)
            elsif element == root && base
              # if the element is the root element of the document, then act as if there is an empty @about present,
              # and process it according to the rule for @about, above;
              uri(base)
            else
              # otherwise, if parent object is present, new subject is set to the value of parent object.
              evaluation_context.parent_object
            end

            if attrs[:typeof]
              typed_resource ||= if attrs[:resource]
                process_uri(element, attrs[:resource], evaluation_context, base,
                            :uri_mappings => uri_mappings,
                            :restrictions => SafeCURIEorCURIEorURI.fetch(@version, []))
              elsif attrs[:href] || attrs[:src]
                process_uri(element, (attrs[:href] || attrs[:src]), evaluation_context, base, :restrictions => [:uri])
              else
                # if none of these are present, the value of typed resource is set to a newly defined bnode.
                RDF::Node.new
              end
              
              # The value of the current object resource is set to the value of typed resource.
              current_object_resource = typed_resource
            end
          else
            # otherwise (ie, the @property element is not present)

            new_subject = if attrs[:about]
              process_uri(element, attrs[:about], evaluation_context, base,
                          :uri_mappings => uri_mappings,
                          :restrictions => SafeCURIEorCURIEorURI.fetch(@version, []))
            elsif attrs[:resource]
              process_uri(element, attrs[:resource], evaluation_context, base,
                          :uri_mappings => uri_mappings,
                          :restrictions => SafeCURIEorCURIEorURI.fetch(@version, []))
            elsif attrs[:href] || attrs[:src]
              process_uri(element, (attrs[:href] || attrs[:src]), evaluation_context, base, :restrictions => [:uri])
            end

            # If no URI is provided by a resource attribute, then the first match from the following rules
            # will apply:
            new_subject ||= if [:xhtml1, :xhtml5, :html4, :html5].include?(@host_language) && element.name =~ /^(head|body)$/
              # From XHTML+RDFa 1.1:
              # if no URI is provided, then first check to see if the element is the head or body element.
              # If it is, then act as if there is an empty @about present, and process it according to the rule for @about.
              uri(base)
            elsif element == root && base
              # if the element is the root element of the document, then act as if there is an empty @about present,
              # and process it according to the rule for @about, above;
              uri(base)
            elsif attrs[:typeof]
              RDF::Node.new
            else
              # otherwise, if parent object is present, new subject is set to the value of parent object.
              # Additionally, if @property is not present then the skip element flag is set to 'true'.
              skip = true unless attrs[:property]
              evaluation_context.parent_object
            end

            # if @typeof is present, set the typed resource to the value of new subject</code>
            typed_resource ||= new_subject if attrs[:typeof]
          end
        end

        add_debug(element) {
          "[Step 5] new_subject: #{new_subject.to_ntriples rescue 'nil'}, " +
          "typed_resource: #{typed_resource.to_ntriples rescue 'nil'}, " +
          "skip = #{skip}"
        }
      else
        # [7.5 Step 6]
        # If the current element does contain a @rel or @rev attribute, then the next step is to
        # establish both a value for new subject and a value for current object resource:
        new_subject = process_uri(element, attrs[:about], evaluation_context, base,
                                  :uri_mappings => uri_mappings,
                                  :restrictions => SafeCURIEorCURIEorURI.fetch(@version, []))
        new_subject ||= process_uri(element, attrs[:src], evaluation_context, base,
                                  :uri_mappings => uri_mappings,
                                  :restrictions => [:uri]) if @version == :"rdfa1.0"
      
        # if the @typeof attribute is present, set typed resource to new subject
        typed_resource = new_subject if attrs[:typeof]

        # If no URI is provided then the first match from the following rules will apply
        new_subject ||= if element == root && base
          uri(base)
        elsif [:xhtml1, :xhtml5, :html4, :html5].include?(@host_language) && element.name =~ /^(head|body)$/
          # From XHTML+RDFa 1.1:
          # if no URI is provided, then first check to see if the element is the head or body element.
          # If it is, then act as if there is an empty @about present, and process it according to the rule for @about.
          uri(base)
        elsif attrs[:typeof] && @version == :"rdfa1.0"
          RDF::Node.new
        else
          # if it's null, it's null and nothing changes
          evaluation_context.parent_object
          # no skip flag set this time
        end
      
        # Then the current object resource is set to the URI obtained from the first match from the following rules:
        current_object_resource = if attrs[:resource]
          process_uri(element, attrs[:resource], evaluation_context, base,
                      :uri_mappings => uri_mappings,
                      :restrictions => SafeCURIEorCURIEorURI.fetch(@version, []))
        elsif attrs[:href]
          process_uri(element, attrs[:href], evaluation_context, base,
                      :restrictions => [:uri])
        elsif attrs[:src] && @version != :"rdfa1.0"
          process_uri(element, attrs[:src], evaluation_context, base,
                      :restrictions => [:uri])
        elsif attrs[:typeof] && !attrs[:about] && @version != :"rdfa1.0"
          # otherwise, if @typeof is present and @about is not and the  incomplete triples
          # within the current context is empty, use a newly created bnode
          RDF::Node.new
        end

        # and also set the value typed resource to this bnode
        if attrs[:typeof]
          if @version == :"rdfa1.0"
            typed_resource = new_subject
          else
            typed_resource = current_object_resource if !attrs[:about]
          end
        end

        add_debug(element) {
          "[Step 6] new_subject: #{new_subject}, " +
          "current_object_resource = #{current_object_resource.nil? ? 'nil' : current_object_resource} " +
          "typed_resource: #{typed_resource.to_ntriples rescue 'nil'}, "
        }
      end
    
      # Process @typeof if there is a subject [Step 7]
      if typed_resource
        # Typeof is TERMorCURIEorAbsURIs
        types = process_uris(element, attrs[:typeof], evaluation_context, base,
                            :uri_mappings => uri_mappings,
                            :term_mappings => term_mappings,
                            :vocab => default_vocabulary,
                            :restrictions => TERMorCURIEorAbsURI.fetch(@version, []))
        add_debug(element, "[Step 7] typeof: #{attrs[:typeof]}")
        types.each do |one_type|
          add_triple(element, typed_resource, RDF["type"], one_type)
        end
      end

      # Create new List mapping [step 8]
      #
      # If in any of the previous steps a new subject was set to a non-null value different from the parent object;
      # The list mapping taken from the evaluation context is set to a new, empty mapping.
      if (new_subject && (new_subject != evaluation_context.parent_subject || list_mapping.nil?))
        list_mapping = {}
        add_debug(element) do
          "[Step 8]: create new list mapping(#{list_mapping.object_id}) " +
            "ns: #{new_subject.to_ntriples}, " +
            "ps: #{evaluation_context.parent_subject.to_ntriples rescue 'nil'}"
        end
      end

      # Generate triples with given object [Step 9]
      #
      # If the current element has a @inlist attribute, add the property to the
      # list associated with that property, creating a new list if necessary.
      if new_subject && current_object_resource && (attrs[:rel] || attrs[:rev])
        add_debug(element) {"[Step 9] rels: #{rels.inspect} revs: #{revs.inspect}"}
        rels.each do |r|
          if attrs[:inlist]
            # If the current list mapping does not contain a list associated with this IRI,
            # instantiate a new list
            unless list_mapping[r]
              list_mapping[r] = RDF::List.new
              add_debug(element) {"list(#{r}): create #{list_mapping[r].inspect}"}
            end
            add_debug(element) {"[Step 9] add #{current_object_resource.to_ntriples} to #{r} #{list_mapping[r].inspect}"}
            list_mapping[r] << current_object_resource
          else
            add_triple(element, new_subject, r, current_object_resource)
          end
        end
      
        revs.each do |r|
          add_triple(element, current_object_resource, r, new_subject)
        end
      elsif attrs[:rel] || attrs[:rev]
        # Incomplete triples and bnode creation [Step 10]
        add_debug(element) {"[Step 10] incompletes: rels: #{rels}, revs: #{revs}"}
        current_object_resource = RDF::Node.new
      
        # predicate: full IRI
        # direction: forward/reverse
        # lists: Save into list, don't generate triple

        rels.each do |r|
          if attrs[:inlist]
            # If the current list mapping does not contain a list associated with this IRI,
            # instantiate a new list
            unless list_mapping[r]
              list_mapping[r] = RDF::List.new
              add_debug(element) {"[Step 10] list(#{r}): create #{list_mapping[r].inspect}"}
            end
            incomplete_triples << {:list => list_mapping[r], :direction => :none}
          else
            incomplete_triples << {:predicate => r, :direction => :forward}
          end
        end
      
        revs.each do |r|
          incomplete_triples << {:predicate => r, :direction => :reverse}
        end
      end
    
      # Establish current object literal [Step 11]
      #
      # If the current element has a @inlist attribute, add the property to the
      # list associated with that property, creating a new list if necessary.
      if attrs[:property]
        properties = process_uris(element, attrs[:property], evaluation_context, base,
                                  :uri_mappings => uri_mappings,
                                  :term_mappings => term_mappings,
                                  :vocab => default_vocabulary,
                                  :restrictions => TERMorCURIEorAbsURIprop.fetch(@version, []))

        properties.reject! do |p|
          if p.is_a?(RDF::URI)
            false
          else
            add_warning(element, "[Step 11] predicate #{p.to_ntriples} must be a URI")
            true
          end
        end

        datatype = process_uri(element, attrs[:datatype], evaluation_context, base,
                              :uri_mappings => uri_mappings,
                              :term_mappings => term_mappings,
                              :vocab => default_vocabulary,
                              :restrictions => TERMorCURIEorAbsURI.fetch(@version, [])) unless attrs[:datatype].to_s.empty?
        begin
          current_property_value = if datatype && datatype != RDF.XMLLiteral
            # typed literal
            add_debug(element, "[Step 11] typed literal (#{datatype})")
            RDF::Literal.new(attrs[:content] || element.inner_text.to_s, :datatype => datatype, :language => language, :validate => validate?, :canonicalize => canonicalize?)
          elsif @version == :"rdfa1.1"
            if datatype == RDF.XMLLiteral
              # XML Literal
              add_debug(element) {"[Step 11(1.1)] XML Literal: #{element.inner_html}"}

              # In order to maintain maximum portability of this literal, any children of the current node that are
              # elements must have the current in scope XML namespace declarations (if any) declared on the
              # serialized element using their respective attributes. Since the child element node could also
              # declare new XML namespaces, the RDFa Processor must be careful to merge these together when
              # generating the serialized element definition. For avoidance of doubt, any re-declarations on the
              # child node must take precedence over declarations that were active on the current node.
              begin
                c14nxl = element.children.c14nxl(
                  :library => @library,
                  :language => language,
                  :namespaces => {nil => XHTML}.merge(namespaces))
                RDF::Literal.new(c14nxl,
                  :library => @library,
                  :datatype => RDF.XMLLiteral,
                  :validate => validate?,
                  :canonicalize => canonicalize?)
              rescue ArgumentError => e
                add_error(element, e.message)
              end
            elsif element.name == 'time'
              # HTML5 support
              # Lexically scan value and assign appropriate type, otherwise, leave untyped
              v = (attrs[:datetime] || element.inner_text).to_s
              datatype = %w(Date Time DateTime Year YearMonth Duration).map {|t| RDF::Literal.const_get(t)}.detect do |dt|
                v.match(dt::GRAMMAR)
              end || RDF::Literal
              add_debug(element) {"[Step 11(1.1)] <time> literal: #{datatype} #{v.inspect}"}
              datatype.new(v)
            elsif attrs[:content]
              # plain literal
              add_debug(element, "[Step 11(1.1)] plain literal (content)")
              RDF::Literal.new(attrs[:content], :language => language, :validate => validate?, :canonicalize => canonicalize?)
            elsif element.name.to_s == 'data' && attrs[:value]
              # HTML5 support
              # plain literal
              add_debug(element, "[Step 11(1.1)] plain literal (value)")
              RDF::Literal.new(attrs[:value],  :language => language, :validate => validate?, :canonicalize => canonicalize?)
            elsif (attrs[:resource] || attrs[:href] || attrs[:src] || attrs[:data]) &&
                 !(attrs[:rel] || attrs[:rev]) &&
                 evaluation_context.incomplete_triples.empty? &&
                 @version != :"rdfa1.0"
              if attrs[:resource]
                add_debug(element, "[Step 11(1.1)] IRI literal (resource)")
                process_uri(element, attrs[:resource], evaluation_context, base,
                            :uri_mappings => uri_mappings,
                            :restrictions => SafeCURIEorCURIEorURI.fetch(@version, []))
              else
                add_debug(element, "[Step 11(1.1)] IRI literal (href/src/data)")
                process_uri(element, (attrs[:href] || attrs[:src] || attrs[:data]), evaluation_context, base, :restrictions => [:uri])
              end
            elsif typed_resource && !attrs[:about] && evaluation_context.incomplete_triples.empty? && @version != :"rdfa1.0"
              add_debug(element, "[Step 11(1.1)] typed_resource")
              typed_resource
            else
              # plain literal
              add_debug(element, "[Step 11(1.1)] plain literal (inner text)")
              RDF::Literal.new(element.inner_text.to_s, :language => language, :validate => validate?, :canonicalize => canonicalize?)
            end
          else
            if element.text_content? || (element.children.length == 0) || attrs[:datatype] == ""
              # plain literal
              add_debug(element, "[Step 11 (1.0)] plain literal")
              RDF::Literal.new(attrs[:content] || element.inner_text.to_s, :language => language, :validate => validate?, :canonicalize => canonicalize?)
            elsif !element.text_content? and (datatype == nil or datatype.to_s == RDF.XMLLiteral.to_s)
              # XML Literal
              add_debug(element) {"[Step 11 (1.0)] XML Literal: #{element.inner_html}"}
              recurse = false
              c14nxl = element.children.c14nxl(
                :library => @library,
                :language => language,
                :namespaces => {nil => XHTML}.merge(namespaces))
              RDF::Literal.new(c14nxl,
                :library => @library,
                :datatype => RDF.XMLLiteral,
                :validate => validate?,
                :canonicalize => canonicalize?)
            end
          end
        rescue ArgumentError => e
          add_error(element, e.message)
        end

        # add each property
        properties.each do |p|
          # Lists: If element has an @inlist attribute, add the value to a list
          if attrs[:inlist]
            # If the current list mapping does not contain a list associated with this IRI,
            # instantiate a new list
            unless list_mapping[p]
              list_mapping[p] = RDF::List.new
              add_debug(element) {"[Step 11] lists(#{p}): create #{list_mapping[p].inspect}"}
            end
            add_debug(element)  {"[Step 11] add #{current_property_value.to_ntriples} to #{p.to_ntriples} #{list_mapping[p].inspect}"}
            list_mapping[p] << current_property_value
          elsif new_subject
            add_triple(element, new_subject, p, current_property_value) 
          end
        end
      end
    
      if !skip and new_subject && !evaluation_context.incomplete_triples.empty?
        # Complete the incomplete triples from the evaluation context [Step 12]
        add_debug(element) do
          "[Step 12] complete incomplete triples: " +
          "new_subject=#{new_subject.to_ntriples}, " +
          "completes=#{evaluation_context.incomplete_triples.inspect}"
        end

        evaluation_context.incomplete_triples.each do |trip|
          case trip[:direction]
          when :none
            add_debug(element) {"[Step 12] add #{new_subject.to_ntriples} to #{trip[:list].inspect}"}
            trip[:list] << new_subject
          when :forward
            add_triple(element, evaluation_context.parent_subject, trip[:predicate], new_subject)
          when :reverse
            add_triple(element, new_subject, trip[:predicate], evaluation_context.parent_subject)
          end
        end
      end

      # Create a new evaluation context and proceed recursively [Step 13]
      if recurse
        if skip
          if language == evaluation_context.language &&
              uri_mappings == evaluation_context.uri_mappings &&
              term_mappings == evaluation_context.term_mappings &&
              default_vocabulary == evaluation_context.default_vocabulary &&
              base == evaluation_context.base &&
              list_mapping == evaluation_context.list_mapping
            new_ec = evaluation_context
            add_debug(element, "[Step 13] skip: reused ec")
          else
            new_ec = evaluation_context.clone
            new_ec.base = base
            new_ec.language = language
            new_ec.uri_mappings = uri_mappings
            new_ec.namespaces = namespaces
            new_ec.term_mappings = term_mappings
            new_ec.default_vocabulary = default_vocabulary
            new_ec.list_mapping = list_mapping
            add_debug(element, "[Step 13] skip: cloned ec")
          end
        else
          # create a new evaluation context
          new_ec = EvaluationContext.new(base, @host_defaults)
          new_ec.parent_subject = new_subject || evaluation_context.parent_subject
          new_ec.parent_object = current_object_resource || new_subject || evaluation_context.parent_subject
          new_ec.uri_mappings = uri_mappings
          new_ec.namespaces = namespaces
          new_ec.incomplete_triples = incomplete_triples
          new_ec.language = language
          new_ec.term_mappings = term_mappings
          new_ec.default_vocabulary = default_vocabulary
          new_ec.list_mapping = list_mapping
          add_debug(element, "[Step 13] new ec")
        end
      
        element.children.each do |child|
          # recurse only if it's an element
          traverse(child, new_ec) if child.element?
        end
        
        # Step 14: after traversing through child elements, for each list associated with
        # a property
        (list_mapping || {}).each do |p, l|
          # if that list is different from the evaluation context
          ec_list = evaluation_context.list_mapping[p] if evaluation_context.list_mapping
          add_debug(element) {"[Step 14] time to create #{l.inspect}? #{(ec_list != l).inspect}"}
          if ec_list != l
            add_debug(element) {"[Step 14] list(#{p}) create #{l.inspect}"}
            # Generate an rdf:List with the elements of that list.
            l.each_statement do |st|
              add_triple(element, st.subject, st.predicate, st.object) unless st.object == RDF.List
            end

            # Generate a triple relating new_subject, property and the list BNode,
            # or rdf:nil if the list is empty.
            if l.empty?
              add_triple(element, new_subject, p, RDF.nil)
            else
              add_triple(element, new_subject, p, l.subject)
            end
          end
        end
      end
    end

    # space-separated TERMorCURIEorAbsURI or SafeCURIEorCURIEorURI
    def process_uris(element, value, evaluation_context, base, options)
      return [] if value.to_s.empty?
      add_debug(element) {"process_uris: #{value}"}
      value.to_s.split(/\s+/).map {|v| process_uri(element, v, evaluation_context, base, options)}.compact
    end

    def process_uri(element, value, evaluation_context, base, options = {})
      return if value.nil?
      restrictions = options[:restrictions]
      add_debug(element) {"process_uri: #{value}, restrictions = #{restrictions.inspect}"}
      options = {:uri_mappings => {}}.merge(options)
      if !options[:term_mappings] && options[:uri_mappings] && value.to_s.match(/^\[(.*)\]$/) && restrictions.include?(:safe_curie)
        # SafeCURIEorCURIEorURI
        # When the value is surrounded by square brackets, then the content within the brackets is
        # evaluated as a CURIE according to the CURIE Syntax definition. If it is not a valid CURIE, the
        # value must be ignored.
        uri = curie_to_resource_or_bnode(element, $1, options[:uri_mappings], evaluation_context.parent_subject, restrictions)
        add_debug(element) {"process_uri: #{value} => safeCURIE => <#{uri}>"}
        uri
      elsif options[:term_mappings] && NC_REGEXP.match(value.to_s) && restrictions.include?(:term)
        # TERMorCURIEorAbsURI
        # If the value is an NCName, then it is evaluated as a term according to General Use of Terms in
        # Attributes. Note that this step may mean that the value is to be ignored.
        uri = process_term(element, value.to_s, options)
        add_debug(element) {"process_uri: #{value} => term => <#{uri}>"}
        uri
      else
        # SafeCURIEorCURIEorURI or TERMorCURIEorAbsURI
        # Otherwise, the value is evaluated as a CURIE.
        # If it is a valid CURIE, the resulting URI is used; otherwise, the value will be processed as a URI.
        uri = curie_to_resource_or_bnode(element, value, options[:uri_mappings], evaluation_context.parent_subject, restrictions)
        if uri
          add_debug(element) {"process_uri: #{value} => CURIE => <#{uri}>"}
        elsif @version == :"rdfa1.0" && value.to_s.match(/^xml/i)
          # Special case to not allow anything starting with XML to be treated as a URI
        elsif restrictions.include?(:absuri) || restrictions.include?(:uri)
          begin
            # AbsURI does not use xml:base
            if restrictions.include?(:absuri)
              uri = uri(value)
              unless uri.absolute?
                uri = nil
                raise RDF::ReaderError, "Relative URI #{value}" 
              end
            else
              uri = uri(base, Addressable::URI.parse(value))
            end
          rescue Addressable::URI::InvalidURIError => e
            add_warning(element, "Malformed prefix #{value}", RDF::RDFA.UnresolvedCURIE)
          rescue RDF::ReaderError => e
            add_debug(element, e.message)
            if value.to_s =~ /^\(^\w\):/
              add_warning(element, "Undefined prefix #{$1}", RDF::RDFA.UnresolvedCURIE)
            else
              add_warning(element, "Relative URI #{value}")
            end
          end
          add_debug(element) {"process_uri: #{value} => URI => <#{uri}>"}
        end
        uri
      end
    end
    
    # [7.4.3] General Use of Terms in Attributes
    def process_term(element, value, options)
      if options[:term_mappings].is_a?(Hash)
        # If the term is in the local term mappings, use the associated URI (case sensitive).
        return uri(options[:term_mappings][value.to_s.to_sym]) if options[:term_mappings].has_key?(value.to_s.to_sym)
        
        # Otherwise, check for case-insensitive match
        options[:term_mappings].each_pair do |term, uri|
          return uri(uri) if term.to_s.downcase == value.to_s.downcase
        end
      end
      
      if options[:vocab]
        # Otherwise, if there is a local default vocabulary the URI is obtained by concatenating that value and the term.
        uri(options[:vocab] + value)
      else
        # Finally, if there is no local default vocabulary, the term has no associated URI and must be ignored.
        add_warning(element, "Term #{value} is not defined", RDF::RDFA.UnresolvedTerm)
        nil
      end
    end

    # From section 6. CURIE Syntax Definition
    def curie_to_resource_or_bnode(element, curie, uri_mappings, subject, restrictions)
      # URI mappings for CURIEs default to XHV, rather than the default doc namespace
      prefix, reference = curie.to_s.split(":")

      # consider the bnode situation
      if prefix == "_" && restrictions.include?(:bnode)
        # we force a non-nil name, otherwise it generates a new name
        # As a special case, _: is also a valid reference for one specific bnode.
        bnode(reference)
      elsif curie.to_s.match(/^:/)
        # Default prefix
        RDF::XHV[reference.to_s]
      elsif !curie.to_s.match(/:/)
        # No prefix, undefined (in this context, it is evaluated as a term elsewhere)
        nil
      else
        # Prefixes always downcased
        prefix = prefix.to_s.downcase unless @version == :"rdfa1.0"
        add_debug(element) do
          "curie_to_resource_or_bnode check for #{prefix.to_s.to_sym.inspect} in #{uri_mappings.inspect}"
        end
        ns = uri_mappings[prefix.to_s.to_sym]
        if ns
          uri(ns + reference.to_s)
        else
          add_debug(element) {"curie_to_resource_or_bnode No namespace mapping for #{prefix}"}
          nil
        end
      end
    end

    def uri(value, append = nil)
      value = RDF::URI.new(value)
      value = value.join(append) if append
      value.validate! if validate?
      value.canonicalize! if canonicalize?
      value = RDF::URI.intern(value) if intern?
      value
    end
  end
end
