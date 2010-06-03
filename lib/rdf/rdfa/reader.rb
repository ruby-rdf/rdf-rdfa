require 'nokogiri'  # FIXME: Implement using different modules as in RDF::TriX

module RDF::RDFa
  ##
  # An RDFa parser in Ruby
  #
  # Ben Adida
  # 2008-05-07
  # Gregg Kellogg
  # 2009-08-04
  class Reader < RDF::Reader
    format Format
  
    NC_REGEXP = Regexp.new(
      %{^
        (?!\\\\u0301)             # &#x301; is a non-spacing acute accent.
                                  # It is legal within an XML Name, but not as the first character.
        (  [a-zA-Z_]
         | \\\\u[0-9a-fA-F]
        )
        (  [0-9a-zA-Z_\.-]
         | \\\\u([0-9a-fA-F]{4})
        )*
      $},
      Regexp::EXTENDED)
  
    XML_LITERAL = RDF['XMLLiteral']
    
    attr_reader :debug

    ##
    # @return [RDF::Graph]
    attr_reader :graph

    # Host language, One of:
    #   :xhtml_rdfa_1_0
    #   :xhtml_rdfa_1_1
    attr_reader :host_language
    
    # The Recursive Baggage
    class EvaluationContext # :nodoc:
      # The base. This will usually be the URL of the document being processed,
      # but it could be some other URL, set by some other mechanism,
      # such as the (X)HTML base element. The important thing is that it establishes
      # a URL against which relative paths can be resolved.
      attr :base, true
      # The parent subject.
      # The initial value will be the same as the initial value of base,
      # but it will usually change during the course of processing.
      attr :parent_subject, true
      # The parent object.
      # In some situations the object of a statement becomes the subject of any nested statements,
      # and this property is used to convey this value.
      # Note that this value may be a bnode, since in some situations a number of nested statements
      # are grouped together on one bnode.
      # This means that the bnode must be set in the containing statement and passed down,
      # and this property is used to convey this value.
      attr :parent_object, true
      # A list of current, in-scope URI mappings.
      attr :uri_mappings, true
      # A list of incomplete triples. A triple can be incomplete when no object resource
      # is provided alongside a predicate that requires a resource (i.e., @rel or @rev).
      # The triples can be completed when a resource becomes available,
      # which will be when the next subject is specified (part of the process called chaining).
      attr :incomplete_triples, true
      # The language. Note that there is no default language.
      attr :language, true
      # The term mappings, a list of terms and their associated URIs.
      # This specification does not define an initial list.
      # Host Languages may define an initial list.
      # If a Host Language provides an initial list, it should do so via an RDFa Profile document.
      attr :term_mappings, true
      # The default vocabulary, a value to use as the prefix URI when a term is used.
      # This specification does not define an initial setting for the default vocabulary.
      # Host Languages may define an initial setting.
      attr :default_vocabulary, true

      def initialize(base, host_defaults)
        # Initialize the evaluation context, [5.1]
        @base = base
        @parent_subject = @base
        @parent_object = nil
        @uri_mappings = {}
        @incomplete_triples = []
        @language = nil
        @term_mappings = host_defaults.fetch(:term_mappings, {})
        @default_voabulary = host_defaults.fetch(:voabulary, nil)
      end

      # Copy this Evaluation Context
      def initialize_copy(from)
          # clone the evaluation context correctly
          @uri_mappings = from.uri_mappings.clone
          @incomplete_triples = from.incomplete_triples.clone
      end
      
      def inspect
        v = %w(base parent_subject parent_object language default_vocabulary).map {|a| "#{a}='#{self.send(a).nil? ? '<nil>' : self.send(a)}'"}
        v << "uri_mappings[#{uri_mappings.keys.length}]"
        v << "incomplete_triples[#{incomplete_triples.length}]"
        v << "term_mappings[#{term_mappings.keys.length}]"
        v.join(",")
      end
    end

    # Parse XHTML+RDFa document from a string or input stream to closure or graph.
    #
    # If the parser is called with a block, triples are passed to the block rather
    # than added to the graph.
    #
    # Optionally, the stream may be a Nokogiri::HTML::Document or Nokogiri::XML::Document
    # With a block, yeilds each statement with URI, BNode or Literal elements
    #
    # @param  [IO] stream:: the HTML+RDFa IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
    # @param [String] uri:: the URI of the document
    # @param [Hash] options:: Parser options, one of
    # <em>options[:debug]</em>:: Array to place debug messages
    # <em>options[:strict]</em>:: Raise Error if true, continue with lax parsing, otherwise
    # @return [Graph]:: Returns the graph containing parsed triples
    # @raise [Error]:: Raises RdfError if _strict_

    ##
    # Initializes the RDFa reader instance.
    #
    # @param  [IO, File, String]       input
    # @param  [Hash{Symbol => Object}] options
    # @yield  [reader]
    # @yieldparam [Reader] reader
    def initialize(input = $stdin, options = {}, &block)
      super
      
        @graph = RDF::Graph.new
        @debug = options[:debug]
        @strict = options[:strict]
        @base_uri = options[:base_uri]
        @base_uri = RDF::URI.parse(@base_uri) if @base_uri.is_a?(String)
        @named_bnodes = {}
        @@vocabulary_cache ||= {}

        @doc = case input
        when Nokogiri::HTML::Document then input
        when Nokogiri::XML::Document then input
        else   Nokogiri::XML.parse(input, @base_uri.to_s)
        end
        
        raise ParserException, "Empty document" if @doc.nil? && @strict
        @callback = block
  
        # Determine host language
        # XXX - right now only XHTML defined
        @host_language = case @doc.root.attributes["version"].to_s
        when /XHTML+RDFa/ then :xhtml
        end
        
        # If none found, assume xhtml
        @host_language ||= :xhtml
        
        @host_defaults = {}
        @host_defaults = case @host_language
        when :xhtml
          {
            :vocabulary => RDF::XHV["uri"],
            :prefix     => "xhv",
            :term_mappings => %w(
              alternate appendix bookmark cite chapter contents copyright first glossary help icon index
              last license meta next p3pv1 prev role section stylesheet subsection start top up
              ).inject({}) { |hash, term| hash[term] = RDF::XHV[term]; hash },
          }
        else
          {}
        end
        
        # parse
        parse_whole_document(@doc, @base_uri)

        block.call(self) if block_given?
    end


    # XXX Invoke the parser, and allow add_triple to make the callback?
    ##
    # Iterates the given block for each RDF statement in the input.
    #
    # @yield  [statement]
    # @yieldparam [RDF::Statement] statement
    # @return [void]
    def each_statement(&block)
      @graph.each_statement(&block)
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
      @graph.each_triple(&block)
    end
    
    private

    # Figure out the document path, if it is a Nokogiri::XML::Element or Attribute
    def node_path(node)
      case node
      when Nokogiri::XML::Element, Nokogiri::XML::Attr then "#{node_path(node.parent)}/#{node.name}"
      when String then node
      else ""
      end
    end
    
    # Add debug event to debug array, if specified
    #
    # @param [XML Node, any] node:: XML Node or string for showing context
    # @param [String] message::
    def add_debug(node, message)
      puts "#{node_path(node)}: #{message}" if $DEBUG
      @debug << "#{node_path(node)}: #{message}" if @debug.is_a?(Array)
    end

    # add a statement, object can be literal or URI or bnode
    #
    # @param [Nokogiri::XML::Node, any] node:: XML Node or string for showing context
    # @param [URI, BNode] subject:: the subject of the statement
    # @param [URI] predicate:: the predicate of the statement
    # @param [URI, BNode, Literal] object:: the object of the statement
    # @return [Statement]:: Added statement
    # @raise [Exception]:: Checks parameter types and raises if they are incorrect if parsing mode is _strict_.
    def add_triple(node, subject, predicate, object)
      statement = RDF::Statement.new(subject, predicate, object)
      add_debug(node, "statement: #{statement}")
      @graph << statement
      statement
    # FIXME: rescue RdfException => e
    rescue Exception => e
      add_debug(node, "add_triple raised #{e.class}: #{e.message}")
      puts e.backtrace if $DEBUG
      raise if @strict
    end

  
    # Parsing an RDFa document (this is *not* the recursive method)
    def parse_whole_document(doc, base)
      # find if the document has a base element
      # XXX - HTML specific
      base_el = doc.css('html>head>base').first
      if (base_el)
        base = base_el.attributes['href']
        # Strip any fragment from base
        base = base.to_s.split("#").first
        @base_uri = RDF::URI.new(base)
        add_debug(base_el, "parse_whole_doc: base='#{base}'")
      end

      # initialize the evaluation context with the appropriate base
      evaluation_context = EvaluationContext.new(base, @host_defaults)

      traverse(doc.root, evaluation_context)
    end
  
    # Extract the XMLNS mappings from an element
    def extract_mappings(element, uri_mappings, term_mappings)
      # Process @profile
      # Next the current element is parsed for any updates to the local term mappings and
      # local list of URI mappings via @profile.
      # If @profile is present, its value is processed as defined in RDFa Profiles.
      element.attributes['profile'].to_s.split(/\s/).each do |profile|
        # Don't try to open ourselves!
        if @base_uri == profile
          add_debug(element, "extract_mappings: skip recursive profile <#{profile}>")
          @@vocabulary_cache[profile]
        elsif @@vocabulary_cache.has_key?(profile)
          add_debug(element, "extract_mappings: skip previously parsed profile <#{profile}>")
        else
          begin
            add_debug(element, "extract_mappings: parse profile <#{profile}>")
            @@vocabulary_cache[profile] = {
              :uri_mappings => {},
              :term_mappings => {}
            }
            um = @@vocabulary_cache[profile][:uri_mappings]
            tm = @@vocabulary_cache[profile][:term_mappings]
            add_debug(element, "extract_mappings: profile open <#{profile}>")
            require 'patron' unless defined?(Patron)
            sess = Patron::Session.new
            sess.timeout = 10
            resp = sess.get(profile)
            raise RuntimeError, "HTTP returned status #{resp.status} when reading #{profile}" if resp.status >= 400
      
            # Parse profile, and extract mappings from graph
            old_debug, old_verbose, = $DEBUG, $verbose
            $DEBUG, $verbose = false, false
            p_graph = Parser.parse(resp.body, profile)
            ttl = p_graph.serialize(:format => :ttl) if @debug || $DEBUG
            $DEBUG, $verbose = old_debug, old_verbose
            add_debug(element, ttl) if ttl
            p_graph.subjects.each do |subject|
              props = p_graph.properties(subject)
              #puts props.inspect
              
              # If one of the objects is not a Literal or if there are additional rdfa:uri or rdfa:term
              # predicates sharing the same subject, no mapping is created.
              uri = props[RDF::RDFA["uri"].to_s]
              term = props[RDF::RDFA["term"].to_s]
              prefix = props[RDF::RDFA["prefix"].to_s]
              add_debug(element, "extract_mappings: uri=#{uri.inspect}, term=#{term.inspect}, prefix=#{prefix.inspect}")

              next if !uri || (!term && !prefix)
              raise ParserException, "multi-valued rdf:uri" if uri.length != 1
              raise ParserException, "multi-valued rdf:term." if term && term.length != 1
              raise ParserException, "multi-valued rdf:prefix" if prefix && prefix.length != 1
            
              uri = uri.first
              term = term.first if term
              prefix = prefix.first if prefix
              raise ParserException, "rdf:uri must be a Literal" unless uri.is_a?(Literal)
              raise ParserException, "rdf:term must be a Literal" unless term.nil? || term.is_a?(Literal)
              raise ParserException, "rdf:prefix must be a Literal" unless prefix.nil? || prefix.is_a?(Literal)
            
              # For every extracted triple that is the common subject of an rdfa:prefix and an rdfa:uri
              # predicate, create a mapping from the object literal of the rdfa:prefix predicate to the
              # object literal of the rdfa:uri predicate. Add or update this mapping in the local list of
              # URI mappings after transforming the 'prefix' component to lower-case.
              # For every extracted
              um[prefix.to_s.downcase] = uri.to_s if prefix
            
              # triple that is the common subject of an rdfa:term and an rdfa:uri predicate, create a
              # mapping from the object literal of the rdfa:term predicate to the object literal of the
              # rdfa:uri predicate. Add or update this mapping in the local term mappings.
              tm[term.to_s] = RDF::URI.new(uri.to_s) if term
            end
          rescue ParserException
            add_debug(element, "extract_mappings: profile subject #{subject.to_s}: #{e.message}")
            raise if @strict
          rescue RuntimeError => e
            add_debug(element, "extract_mappings: profile: #{e.message}")
            raise if @strict
          end
        end
        
        # Merge mappings from this vocabulary
        uri_mappings.merge!(@@vocabulary_cache[profile][:uri_mappings])
        term_mappings.merge!(@@vocabulary_cache[profile][:term_mappings])
      end
      
      # look for xmlns
      # (note, this may be dependent on @host_language)
      # Regardless of how the mapping is declared, the value to be mapped must be converted to lower case,
      # and the URI is not processed in any way; in particular if it is a relative path it is
      # not resolved against the current base.
      element.namespaces.each do |attr_name, attr_value|
        begin
          abbr, prefix = attr_name.split(":")
          uri_mappings[prefix.to_s.downcase] = attr_value if abbr.downcase == "xmlns" && prefix
        # FIXME: rescue RdfException => e
        rescue Exception => e
          add_debug(element, "extract_mappings raised #{e.class}: #{e.message}")
          raise if @strict
        end
      end

      # Set mappings from @prefix
      # prefix is a whitespace separated list of prefix-name URI pairs of the form
      #   NCName ':' ' '+ xs:anyURI
      # SPEC Confusion: prefix is forced to lower-case in @profile, but not specified here.
      mappings = element.attributes["prefix"].to_s.split(/\s+/)
      while mappings.length > 0 do
        prefix, uri = mappings.shift.downcase, mappings.shift
        #puts "uri_mappings prefix #{prefix} <#{uri}>"
        next unless prefix.match(/:$/)
        prefix.chop!
        
        uri_mappings[prefix] = uri
      end
      
      add_debug(element, "uri_mappings: #{uri_mappings.values.map{|ns|ns.to_s}.join(", ")}")
      add_debug(element, "term_mappings: #{term_mappings.keys.join(", ")}")
    end

    # The recursive helper function
    def traverse(element, evaluation_context)
      if element.nil?
        add_debug(element, "traverse nil element")
        raise ParserException, "Can't parse nil element" if @strict
        return nil
      end
      
      add_debug(element, "traverse, ec: #{evaluation_context.inspect}")

      # local variables [5.5 Step 1]
      recurse = true
      skip = false
      new_subject = nil
      current_object_resource = nil
      uri_mappings = evaluation_context.uri_mappings.clone
      incomplete_triples = []
      language = evaluation_context.language
      term_mappings = evaluation_context.term_mappings.clone
      default_vocabulary = evaluation_context.default_vocabulary

      current_object_literal = nil  # XXX Not explicit
    
      # shortcut
      attrs = element.attributes

      about = attrs['about']
      src = attrs['src']
      resource = attrs['resource']
      href = attrs['href']
      vocab = attrs['vocab']

      # Pull out the attributes needed for the skip test.
      property = attrs['property'].to_s if attrs['property']
      typeof = attrs['typeof'].to_s if attrs['typeof']
      datatype = attrs['datatype'].to_s if attrs['datatype']
      content = attrs['content'].to_s if attrs['content']
      rel = attrs['rel'].to_s if attrs['rel']
      rev = attrs['rev'].to_s if attrs['rev']

      # Default vocabulary [7.5 Step 2]
      # First the current element is examined for any change to the default vocabulary via @vocab.
      # If @vocab is present and contains a value, its value updates the local default vocabulary.
      # If the value is empty, then the local default vocabulary must be reset to the Host Language defined default.
      unless vocab.nil?
        default_vocabulary = if vocab.to_s.empty?
          # Set default_vocabulary to host language default
          @host_defaults.fetch(:voabulary, nil)
        else
          vocab.to_s
        end
        add_debug(element, "[Step 2] traverse, default_vocaulary: #{default_vocabulary.inspect}")
      end
      
      # Local term mappings [7.5 Steps 3 & 4]
      # Next the current element is parsed for any updates to the local term mappings and local list of URI mappings via @profile.
      # If @profile is present, its value is processed as defined in RDFa Profiles.
      extract_mappings(element, uri_mappings, term_mappings)
    
      # Language information [7.5 Step 5]
      # From HTML5 [3.2.3.3]
      #   If both the lang attribute in no namespace and the lang attribute in the XML namespace are set
      #   on an element, user agents must use the lang attribute in the XML namespace, and the lang
      #   attribute in no namespace must be ignored for the purposes of determining the element's
      #   language.
      language = case
      when element.at_xpath("@xml:lang", "xml" => RDF::XML["uri"].to_s)
        element.at_xpath("@xml:lang", "xml" => RDF::XML["uri"].to_s).to_s
      when element.at_xpath("lang")
        element.at_xpath("lang").to_s
      else
        language
      end
      add_debug(element, "HTML5 [3.2.3.3] traverse, lang: #{language}") if attrs['lang']
    
      # rels and revs
      rels = process_uris(element, rel, evaluation_context, :uri_mappings => uri_mappings, :term_mappings => term_mappings, :vocab => default_vocabulary)
      revs = process_uris(element, rev, evaluation_context, :uri_mappings => uri_mappings, :term_mappings => term_mappings, :vocab => default_vocabulary)
    
      add_debug(element, "traverse, about: #{about.nil? ? 'nil' : about}, src: #{src.nil? ? 'nil' : src}, resource: #{resource.nil? ? 'nil' : resource}, href: #{href.nil? ? 'nil' : href}")
      add_debug(element, "traverse, property: #{property.nil? ? 'nil' : property}, typeof: #{typeof.nil? ? 'nil' : typeof}, datatype: #{datatype.nil? ? 'nil' : datatype}, content: #{content.nil? ? 'nil' : content}")
      add_debug(element, "traverse, rels: #{rels.join(" ")}, revs: #{revs.join(" ")}")

      if !(rel || rev)
        # Establishing a new subject if no rel/rev [7.5 Step 6]
        # May not be valid, but can exist
        if about
          new_subject = process_uri(element, about, evaluation_context, :uri_mappings => uri_mappings)
        elsif src
          new_subject = process_uri(element, src, evaluation_context)
        elsif resource
          new_subject =  process_uri(element, resource, evaluation_context, :uri_mappings => uri_mappings)
        elsif href
          new_subject = process_uri(element, href, evaluation_context)
        end

        # If no URI is provided by a resource attribute, then the first match from the following rules
        # will apply:
        #   if @typeof is present, then new subject is set to be a newly created bnode.
        # otherwise,
        #   if parent object is present, new subject is set to the value of parent object.
        # Additionally, if @property is not present then the skip element flag is set to 'true';
        if new_subject.nil?
          if @host_language == :xhtml && element.name =~ /^(head|body)$/ && evaluation_context.base
            # From XHTML+RDFa 1.1:
            # if no URI is provided, then first check to see if the element is the head or body element.
            # If it is, then act as if there is an empty @about present, and process it according to the rule for @about.
            new_subject = RDF::URI.new(evaluation_context.base)
          elsif element.attributes['typeof']
            new_subject = RDF::Node.new
          else
            # if it's null, it's null and nothing changes
            new_subject = evaluation_context.parent_object
            skip = true unless property
          end
        end
        add_debug(element, "[Step 6] new_subject: #{new_subject}, skip = #{skip}")
      else
        # [7.5 Step 7]
        # If the current element does contain a @rel or @rev attribute, then the next step is to
        # establish both a value for new subject and a value for current object resource:
        if about
          new_subject =  process_uri(element, about, evaluation_context, :uri_mappings => uri_mappings)
        elsif src
          new_subject =  process_uri(element, src, evaluation_context, :uri_mappings => uri_mappings)
        end
      
        # If no URI is provided then the first match from the following rules will apply
        if new_subject.nil?
          if @host_language == :xhtml && element.name =~ /^(head|body)$/
            # From XHTML+RDFa 1.1:
            # if no URI is provided, then first check to see if the element is the head or body element.
            # If it is, then act as if there is an empty @about present, and process it according to the rule for @about.
            new_subject = RDF::URI.new(evaluation_context.base)
          elsif element.attributes['typeof']
            new_subject = RDF::Node.new
          else
            # if it's null, it's null and nothing changes
            new_subject = evaluation_context.parent_object
            # no skip flag set this time
          end
        end
      
        # Then the current object resource is set to the URI obtained from the first match from the following rules:
        if resource
          current_object_resource =  process_uri(element, resource, evaluation_context, :uri_mappings => uri_mappings)
        elsif href
          current_object_resource = process_uri(element, href, evaluation_context)
        end

        add_debug(element, "[Step 7] new_subject: #{new_subject}, current_object_resource = #{current_object_resource.nil? ? 'nil' : current_object_resource}")
      end
    
      # Process @typeof if there is a subject [Step 8]
      if new_subject and typeof
        # Typeof is TERMorCURIEorURIs
        types = process_uris(element, typeof, evaluation_context, :uri_mappings => uri_mappings, :term_mappings => term_mappings, :vocab => default_vocabulary)
        add_debug(element, "typeof: #{typeof}")
        types.each do |one_type|
          add_triple(element, new_subject, RDF_TYPE, one_type)
        end
      end
    
      # Generate triples with given object [Step 9]
      if current_object_resource
        rels.each do |r|
          add_triple(element, new_subject, r, current_object_resource)
        end
      
        revs.each do |r|
          add_triple(element, current_object_resource, r, new_subject)
        end
      elsif rel || rev
        # Incomplete triples and bnode creation [Step 10]
        add_debug(element, "[Step 10] incompletes: rels: #{rels}, revs: #{revs}")
        current_object_resource = RDF::Node.new
      
        rels.each do |r|
          incomplete_triples << {:predicate => r, :direction => :forward}
        end
      
        revs.each do |r|
          incomplete_triples << {:predicate => r, :direction => :reverse}
        end
      end
    
      # Establish current object literal [Step 11]
      if property
        properties = process_uris(element, property, evaluation_context, :uri_mappings => uri_mappings, :term_mappings => term_mappings, :vocab => default_vocabulary)

        # get the literal datatype
        type = datatype
        children_node_types = element.children.collect{|c| c.class}.uniq
      
        # the following 3 IF clauses should be mutually exclusive. Written as is to prevent extensive indentation.
        type_resource = process_uri(element, type, evaluation_context, :uri_mappings => uri_mappings, :term_mappings => term_mappings, :vocab => default_vocabulary) if type
        if type and !type.empty? and (type_resource.to_s != XML_LITERAL.to_s)
          # typed literal
          add_debug(element, "[Step 11] typed literal")
          current_object_literal = RDF::Literal.new(content || element.inner_text, :datatype => type_resource, :language => language)
        elsif content or (children_node_types == [Nokogiri::XML::Text]) or (element.children.length == 0) or (type == '')
          # plain literal
          add_debug(element, "[Step 11] plain literal")
          current_object_literal = RDF::Literal.new(content || element.inner_text, :language => language)
        elsif children_node_types != [Nokogiri::XML::Text] and (type == nil or type_resource.to_s == XML_LITERAL.to_s)
          # XML Literal
          add_debug(element, "[Step 11] XML Literal: #{element.inner_html}")
          current_object_literal = RDF::Literal.new(element.inner_html, :datatype => XML_LITERAL, :language => language, :namespaces => uri_mappings)
          recurse = false
        end
      
        # add each property
        properties.each do |p|
          add_triple(element, new_subject, p, current_object_literal)
        end
        # SPEC CONFUSION: "the triple has been created" ==> there may be more than one
        # set the recurse flag above in the IF about xmlliteral, as it is the only place that can happen
      end
    
      if not skip and new_subject && !evaluation_context.incomplete_triples.empty?
        # Complete the incomplete triples from the evaluation context [Step 12]
        add_debug(element, "[Step 12] complete incomplete triples: new_subject=#{new_subject}, completes=#{evaluation_context.incomplete_triples.inspect}")
        evaluation_context.incomplete_triples.each do |trip|
          if trip[:direction] == :forward
            add_triple(element, evaluation_context.parent_subject, trip[:predicate], new_subject)
          elsif trip[:direction] == :reverse
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
            new_ec = evaluation_context
            add_debug(element, "[Step 13] skip: reused ec")
          else
            new_ec = evaluation_context.clone
            new_ec.language = language
            new_ec.uri_mappings = uri_mappings
            new_ec.term_mappings = term_mappings
            new_ec.default_vocabulary = default_vocabulary
            add_debug(element, "[Step 13] skip: cloned ec")
          end
        else
          # create a new evaluation context
          new_ec = EvaluationContext.new(evaluation_context.base, @host_defaults)
          new_ec.parent_subject = new_subject || evaluation_context.parent_subject
          new_ec.parent_object = current_object_resource || new_subject || evaluation_context.parent_subject
          new_ec.uri_mappings = uri_mappings
          new_ec.incomplete_triples = incomplete_triples
          new_ec.language = language
          new_ec.term_mappings = term_mappings
          new_ec.default_vocabulary = default_vocabulary
          add_debug(element, "[Step 13] new ec")
        end
      
        element.children.each do |child|
          # recurse only if it's an element
          traverse(child, new_ec) if child.class == Nokogiri::XML::Element
        end
      end
    end

    # space-separated TERMorCURIEorURI
    def process_uris(element, value, evaluation_context, options)
      return [] if value.to_s.empty?
      add_debug(element, "process_uris: #{value}")
      value.to_s.split(/\s+/).map {|v| process_uri(element, v, evaluation_context, options)}.compact
    end

    def process_uri(element, value, evaluation_context, options = {})
      #return if value.to_s.empty?
      #add_debug(element, "process_uri: #{value}")
      options = {:uri_mappings => {}}.merge(options)
      if !options[:term_mappings] && options[:uri_mappings] && value.to_s.match(/^\[(.*)\]$/)
        # SafeCURIEorCURIEorURI
        # When the value is surrounded by square brackets, then the content within the brackets is
        # evaluated as a CURIE according to the CURIE Syntax definition. If it is not a valid CURIE, the
        # value must be ignored.
        uri = curie_to_resource_or_bnode(element, $1, options[:uri_mappings], evaluation_context.parent_subject)
        add_debug(element, "process_uri: #{value} => safeCURIE => <#{uri}>")
        uri
      elsif options[:term_mappings] && NC_REGEXP.match(value.to_s)
        # TERMorCURIEorURI
        # If the value is an NCName, then it is evaluated as a term according to General Use of Terms in
        # Attributes. Note that this step may mean that the value is to be ignored.
        uri = process_term(value.to_s, options)
        add_debug(element, "process_uri: #{value} => term => <#{uri}>")
        uri
      else
        # SafeCURIEorCURIEorURI or TERMorCURIEorURI
        # Otherwise, the value is evaluated as a CURIE.
        # If it is a valid CURIE, the resulting URI is used; otherwise, the value will be processed as a URI.
        uri = curie_to_resource_or_bnode(element, value, options[:uri_mappings], evaluation_context.parent_subject)
        if uri
          add_debug(element, "process_uri: #{value} => CURIE => <#{uri}>")
        else
          #FIXME: uri = URIRef.new(value, evaluation_context.base)
          uri = RDF::URI.new(value)
          add_debug(element, "process_uri: #{value} => URI => <#{uri}>")
        end
        uri
      end
    end
    
    # [7.4.3] General Use of Terms in Attributes
    #
    # @param [String] term:: term
    # @param [Hash] options:: Parser options, one of
    # <em>options[:term_mappings]</em>:: Term mappings
    # <em>options[:vocab]</em>:: Default vocabulary
    def process_term(value, options)
      case
      when options[:term_mappings].is_a?(Hash) && options[:term_mappings].has_key?(value.to_s.downcase)
        # If the term is in the local term mappings, use the associated URI.
        # XXX Spec Confusion: are terms always downcased? Or only for XHTML Vocab?
        options[:term_mappings][value.to_s.downcase]
      when options[:vocab]
        # Otherwise, if there is a local default vocabulary the URI is obtained by concatenating that value and the term.
        options[:vocab] + value
      else
        # Finally, if there is no local default vocabulary, the term has no associated URI and must be ignored.
        nil
      end
    end

    # From section 6. CURIE Syntax Definition
    def curie_to_resource_or_bnode(element, curie, uri_mappings, subject)
      # URI mappings for CURIEs default to XHV, rather than the default doc namespace
      prefix, reference = curie.to_s.split(":")

      # consider the bnode situation
      if prefix == "_"
        # we force a non-nil name, otherwise it generates a new name
        # FIXME: BNode.new(reference || "", @named_bnodes)
        RDF::Node.new(reference || nil)
      elsif curie.to_s.match(/^:/)
        # Default prefix
        if uri_mappings[""]
          uri_mappings[""].send("#{reference}_")
        elsif @host_defaults[:prefix]
          @host_defaults[:prefix].send("#{reference}_")
        end
      elsif !curie.to_s.match(/:/)
        # No prefix, undefined (in this context, it is evaluated as a term elsewhere)
        nil
      else
        # XXX Spec Confusion, are prefixes always downcased?
        ns = uri_mappings[prefix.to_s.downcase]
        if ns
          ns + reference
        else
          add_debug(element, "curie_to_resource_or_bnode No namespace mapping for #{prefix.downcase}")
          nil
        end
      end
    end
  end
end