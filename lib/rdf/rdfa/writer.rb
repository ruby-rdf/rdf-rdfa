require 'haml'
require 'rdf/rdfa/patches/graph_properties'

module RDF::RDFa
  ##
  # An RDFa 1.1 serialiser in Ruby. The RDFa serializer makes use of Haml templates,
  # allowing runtime-replacement with alternate templates. Note, however, that templates
  # should be checked against the W3C test suite to ensure that valid RDFa is emitted.
  #
  # Note that the natural interface is to write a whole graph at a time.
  # Writing statements or Triples will create a graph to add them to
  # and then serialize the graph.
  #
  # The writer will add prefix definitions, and use them for creating @prefix definitions, and minting CURIEs
  #
  # @example Obtaining a RDFa writer class
  #   RDF::Writer.for(:html)         #=> RDF::RDFa::Writer
  #   RDF::Writer.for("etc/test.html")
  #   RDF::Writer.for(:file_name      => "etc/test.html")
  #   RDF::Writer.for(:file_extension => "html")
  #   RDF::Writer.for(:content_type   => "application/xhtml+xml")
  #   RDF::Writer.for(:content_type   => "text/html")
  #
  # @example Serializing RDF graph into an XHTML+RDFa file
  #   RDF::RDFa::Write.open("etc/test.html") do |writer|
  #     writer << graph
  #   end
  #
  # @example Serializing RDF statements into an XHTML+RDFa file
  #   RDF::RDFa::Writer.open("etc/test.html") do |writer|
  #     graph.each_statement do |statement|
  #       writer << statement
  #     end
  #   end
  #
  # @example Serializing RDF statements into an XHTML+RDFa string
  #   RDF::RDFa::Writer.buffer do |writer|
  #     graph.each_statement do |statement|
  #       writer << statement
  #     end
  #   end
  #
  # @example Creating @base and @prefix definitions in output
  #   RDF::RDFa::Writer.buffer(:base_uri => "http://example.com/", :prefixes => {
  #       :foaf => "http://xmlns.com/foaf/0.1/"}
  #   ) do |writer|
  #     graph.each_statement do |statement|
  #       writer << statement
  #     end
  #   end
  #
  # @example Creating @profile definitions in output
  #   RDF::RDFa::Writer.buffer(:profile => "http://example.com/profile") do |writer|
  #     graph.each_statement do |statement|
  #       writer << statement
  #     end
  #   end
  #
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  class Writer < RDF::Writer
    format RDF::RDFa::Format
    
    # Defines rdf:type of subjects to be emitted at the beginning of the document.
    # @return [Array<URI>]
    attr :top_classes
    
    # Defines order of predicates to use in heading.
    # @return [Array<URI>]
    attr :heading_predicates

    HAML_OPTIONS = {
      :ugly => true, # to preserve whitespace without using entities
    }

    # @return [Graph] Graph of statements serialized
    attr_accessor :graph

    # @return [URI] Base URI used for relativizing URIs
    attr_accessor :base_uri
    
    ##
    # Initializes the RDFa writer instance.
    #
    # @param  [IO, File] output
    #   the output stream
    # @param  [Hash{Symbol => Object}] options
    #   any additional options
    # @option options [Boolean]  :canonicalize (false)
    #   whether to canonicalize literals when serializing
    # @option options [Hash]     :prefixes     (Hash.new)
    #   the prefix mappings to use
    # @option options [#to_a]     :profiles     (Array.new)
    #   List of profiles to add to document. This will use terms, prefix definitions and default-vocabularies
    #   identified within the profiles (taken in reverse order) to determine how to serialize terms
    # @option options [#to_s]    :base_uri     (nil)
    #   the base URI to use when constructing relative URIs, set as html>head>base.href
    # @option options [#to_s]   :lang   (nil)
    #   Output as root @lang attribute, and avoid generation _@lang_ where possible
    # @option options [Boolean]  :standard_prefixes   (false)
    #   Add standard prefixes to _prefixes_, if necessary.
    # @option options [Repository] :profile_repository (nil)
    #   Repository to find and save profile graphs.
    # @option options [Array<RDF::URI>] :top_classes ([RDF::RDFS.Class])
    #   Defines rdf:type of subjects to be emitted at the beginning of the document.
    # @option options [Array<RDF::URI>] :heading_predicates ([RDF::RDFS.label, RDF::DC.title])
    #   Defines order of predicates to use in heading.
    # @option options [Hash{Symbol => String}] :haml (DEFAULT_HAML)
    #   HAML templates used for generating code
    # @option options [Hash] :haml_options (HAML_OPTIONS)
    #   Options to pass to Haml::Engine.new. Default options set :ugly => true
    #   to ensure that whitespace in literals with newlines is properly preserved.
    # @yield  [writer]
    # @yieldparam [RDF::Writer] writer
    def initialize(output = $stdout, options = {}, &block)
      self.profile_repository = options[:profile_repository] if options[:profile_repository]
      super do
        @uri_to_term_or_curie = {}
        @uri_to_prefix = {}
        @top_classes = options[:top_classes] || [RDF::RDFS.Class]
        @heading_predicates = options[:heading_predicates] || [RDF::RDFS.label, RDF::DC.title]
        @graph = RDF::Graph.new

        block.call(self) if block_given?
      end
    end

    # @return [Hash<Symbol => String>]
    def haml_template
      @options[:haml] || DEFAULT_HAML
    end

    # @return [RDF::Repository]
    def profile_repository
      Profile.repository
    end
    
    # @param [RDF::Repository] repo
    # @return [RDF::Repository]
    def profile_repository=(repo)
      Profile.repository = repo
    end
    
    ##
    # Write whole graph
    #
    # @param  [Graph] graph
    # @return [void]
    def write_graph(graph)
      @graph = graph
    end

    ##
    # Addes a statement to be serialized
    # @param  [RDF::Statement] statement
    # @return [void]
    def write_statement(statement)
      @graph.insert(statement)
    end

    ##
    # Addes a triple to be serialized
    # @param  [RDF::Resource] subject
    # @param  [RDF::URI]      predicate
    # @param  [RDF::Value]    object
    # @return [void]
    # @raise  [NotImplementedError] unless implemented in subclass
    # @abstract
    def write_triple(subject, predicate, object)
      @graph.insert(Statement.new(subject, predicate, object))
    end

    ##
    # Outputs the XHTML+RDFa representation of all stored triples.
    #
    # @return [void]
    def write_epilogue
      @base_uri = @options[:base_uri]
      @lang = @options[:lang]
      @debug = @options[:debug]
      self.reset

      add_debug "\nserialize: graph size: #{@graph.size}"

      preprocess

      add_debug "\nserialize: graph prefixes: #{prefixes.inspect}"

      # Profiles
      profile = @options[:profiles].join(" ") if @options[:profiles]

      # Prefixes
      prefix = prefixes.keys.map {|pk| "#{pk}: #{prefixes[pk]}"}.sort.join(" ") unless prefixes.empty?

      subjects = order_subjects
      
      # If the first subject has a predicate which we recognize has being for a title,
      # use it as the document title.
      @graph.properties(subjects.first).each do |pred, value|
        next unless heading_predicates.include?(pred)
        @doc_title ||= value.first
      end

      # Generate document
      doc = render_document(subjects,
        :lang     => @lang,
        :base     => @base_uri,
        :title    => @doc_title,
        :profile  => profile,
        :prefix   => prefix) do |s|
        subject(s)
      end
      @output.write(doc)
    end

    protected

    # Render document using haml_template[:doc].
    # Yields each subject to be rendered separately.
    #
    # The default Haml template is:
    #     !!! XML
    #     !!! 5
    #     %html{:xmlns => "http://www.w3.org/1999/xhtml", :lang => lang, :profile => profile, :prefix => prefix}
    #       - if base || title
    #         %head
    #           - if base
    #             %base{:href => base}
    #           - if title
    #             %title= title
    #       %body
    #         - subjects.each do |subject|
    #           != yield(subject)
    #
    # @param [Array<RDF::Resource>] subjects
    #   Ordered list of subjects. Template must yield to each subject, which returns
    #   the serialization of that subject (@see subject_template)
    # @param [Hash{Symbol => Object}] options Rendering options passed to Haml render.
    # @option options [RDF::URI] base (nil)
    #   Base URI added to document, used for shortening URIs within the document.
    # @option options [Symbol, String] language (nil)
    #   Value of @lang attribute in document, also allows included literals to omit
    #   an @lang attribute if it is equivalent to that of the document.
    # @option options [String] title (nil)
    #   Value of html>head>title element.
    # @option options [String] profile (nil)
    #   Value of @profile attribute.
    # @option options [String] prefix (nil)
    #   Value of @prefix attribute.
    # @option options [String] haml (haml_template[:doc])
    #   Haml template to render.
    # @yield [subject]
    #   Yields each subject
    # @yieldparam [RDF::URI] subject
    # @yieldreturn [:ignored]
    # @return String
    #   The rendered document is returned as a string
    def render_document(subjects, options = {})
      template = options[:haml] || :doc
      options = {
        :prefix => nil,
        :profile => nil,
        :subjects => subjects,
        :title => nil,
      }.merge(options)
      hamlify(template, options) do |subject|
        yield(subject) if block_given?
      end
    end
    
    # Render a subject using haml_template[:subject].
    #
    # The _subject_ template may be called either as a top-level element, or recursively under another element
    # if the _rel_ local is not nil.
    #
    # Yields each predicate/property to be rendered separately (@see render_property_value and
    # render_property_values).
    #
    # The default Haml template is:
    #     - if element == :li
    #       %li{:about => get_curie(subject), :typeof => typeof}
    #         - if typeof
    #           %span.type!= typeof
    #         - predicates.each do |predicate|
    #           != yield(predicate)
    #     - elsif rel && typeof
    #       %div{:rel => get_curie(rel)}
    #         %div{:about => get_curie(subject), :typeof => typeof}
    #           %span.type!= typeof
    #           - predicates.each do |predicate|
    #             != yield(predicate)
    #     - elsif rel
    #       %div{:rel => get_curie(rel), :resource => get_curie(subject)}
    #         - predicates.each do |predicate|
    #           != yield(predicate)
    #     - else
    #       %div{:about => get_curie(subject), :typeof => typeof}
    #         - if typeof
    #           %span.type!= typeof
    #         - predicates.each do |predicate|
    #           != yield(predicate)
    #
    # @param [Array<RDF::Resource>] subject
    #   Subject to render
    # @param [Array<RDF::Resource>] predicates
    #   Predicates of subject. Each property is yielded for separate rendering.
    # @param [Hash{Symbol => Object}] options Rendering options passed to Haml render.
    # @option options [String] about (nil)
    #   About description, a CURIE, URI or Node definition.
    #   May be nil if no @about is rendered (e.g. unreferenced Nodes)
    # @option options [String] resource (nil)
    #   Resource description, a CURIE, URI or Node definition.
    #   May be nil if no @resource is rendered
    # @option options [String] rel (nil)
    #   Optional @rel property description, a CURIE, URI or Node definition.
    # @option options [String] typeof (nil)
    #   RDF type as a CURIE, URI or Node definition.
    #   If :about is nil, this defaults to the empty string ("").
    # @option options [:li, nil] element (nil)
    #   Render with <li>, otherwise with template default.
    # @option options [String] haml (haml_template[:subject])
    #   Haml template to render.
    # @yield [predicate]
    #   Yields each predicate
    # @yieldparam [RDF::URI] predicate
    # @yieldreturn [:ignored]
    # @return String
    #   The rendered document is returned as a string
    # Return Haml template for document from haml_template[:subject]
    def render_subject(subject, predicates, options = {})
      template = options[:haml] || :subject
      options = {
        :about      => (get_curie(subject) unless options[:rel]),
        :element    => nil,
        :predicates => predicates,
        :rel        => nil,
        :resource   => (get_curie(subject) if options[:rel]),
        :subject    => subject,
        :typeof     => nil,
      }.merge(options)
      hamlify(template, options) do |predicate|
        yield(predicate) if block_given?
      end
    end
    
    # Render a single- or multi-valued predicate using haml_template[:property_value] or haml_template[:property_values].
    # Yields each object for optional rendering. The block should only
    # render for recursive subject definitions (i.e., where the object
    # is also a subject and is rendered underneath the first referencing subject).
    #
    # The default Haml template for a single-valued property is:
    #     - object = objects.first
    #     - if heading_predicates.include?(predicate) && object.literal?
    #       %h1{:property => get_curie(predicate), :content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object)}&= get_value(object)
    #     - else
    #       %div.property
    #         %span.label
    #           = get_predicate_name(predicate)
    #         - if res = yield(object)
    #           != res
    #         - elsif object.node?
    #           %span{:resource => get_curie(object), :rel => get_curie(predicate)}= get_curie(object)
    #         - elsif object.uri?
    #           %a{:href => object.to_s, :rel => get_curie(predicate)}= object.to_s
    #         - elsif object.datatype == RDF.XMLLiteral
    #           %span{:property => get_curie(predicate), :lang => get_lang(object), :datatype => get_dt_curie(object)}<!= get_value(object)
    #         - else
    #           %span{:property => get_curie(predicate), :content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object)}&= get_value(object)
    #
    # The default Haml template for a multi-valued property is:
    #   %div.property
    #     %span.label
    #       = get_predicate_name(predicate)
    #     %ul{:rel => (get_curie(rel) if rel), :property => (get_curie(property) if property)}
    #       - objects.each do |object|
    #         - if res = yield(object)
    #           != res
    #         - elsif object.node?
    #           %li{:resource => get_curie(object)}= get_curie(object)
    #         - elsif object.uri?
    #           %li
    #             %a{:href => object.to_s}= object.to_s
    #         - elsif object.datatype == RDF.XMLLiteral
    #           %li{:lang => get_lang(object), :datatype => get_curie(object.datatype)}<!= get_value(object)
    #         - else
    #           %li{:content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object)}&= get_value(object)
    #
    # @param [Array<RDF::Resource>] predicate
    #   Predicate to render.
    # @param [Array<RDF::Resource>] objects
    #   List of objects to render.
    #   If the list contains only a single element, the :property_value template will be used.
    #   Otherwise, the :property_values template is used.
    # @param [RDF::Resource] property
    #   Value of @property, which should only be defined for literal objects
    # @param [RDF::Resource] rel
    #   Value of @rel, which should only be defined for Node or URI objects.
    # @param [Hash{Symbol => Object}] options Rendering options passed to Haml render.
    # @option options [String] haml (haml_template[:property_value], haml_template[:property_values])
    #   Haml template to render. Otherwise, uses haml_template[:property_value] or haml_template[:property_values]
    #   depending on the cardinality of objects.
    # @yield [object]
    #   Yields object.
    # @yieldparam [RDF::Resource] object
    # @yieldreturn [String, nil]
    #   The block should only return a string for recursive object definitions.
    # @return String
    #   The rendered document is returned as a string
    def render_property(predicate, objects, property, rel, options = {})
      template = options[:haml] || (objects.to_a.length == 1 ? :property_value : :property_values)
      options = {
        :objects    => objects,
        :predicate  => predicate,
        :property   => property,
        :rel        => rel,
      }.merge(options)
      hamlify(template, options) do |object|
        yield(object) if block_given?
      end
    end
    
    # Perform any preprocessing of statements required
    # @return [ignored]
    def preprocess
      # Load profiles
      # Add terms and prefixes to local store for converting URIs
      # Keep track of vocabulary from left-most profile
      [@options[:profiles]].flatten.compact.reverse.each do |uri|
        prof = Profile.find(uri)
        prof.prefixes.each_pair do |k, v|
          @uri_to_prefix[v] = k
        end
        
        prof.terms.each_pair do |k, v|
          @uri_to_term_or_curie[v] = RDF::URI.intern(k)
        end
        
        @vocabulary = prof.vocabulary.to_s
      end
      
      # Load defined prefixes
      (@options[:prefixes] || {}).each_pair do |k, v|
        @uri_to_prefix[v.to_s] = k
      end
      @options[:prefixes] = {}  # Will define actual used when matched
      
      # Process each statement to establish CURIEs and Terms
      @graph.each {|statement| preprocess_statement(statement)}
    end
    
    # Order subjects for output. Override this to output subjects in another order.
    #
    # Uses top_classes
    # @return [Array<Resource>] Ordered list of subjects
    def order_subjects
      seen = {}
      subjects = []
      
      top_classes.each do |class_uri|
        graph.query(:predicate => RDF.type, :object => class_uri).map {|st| st.subject}.sort.uniq.each do |subject|
          #add_debug "order_subjects: #{subject.inspect}"
          subjects << subject
          seen[subject] = @top_levels[subject] = true
        end
      end
      
      # Sort subjects by resources over nodes, ref_counts and the subject URI itself
      recursable = @subjects.keys.
        select {|s| !seen.include?(s)}.
        map {|r| [r.is_a?(RDF::Node) ? 1 : 0, ref_count(r), r]}.
        sort
      
      subjects += recursable.map{|r| r.last}
    end
    
    # Take a hash from predicate uris to lists of values.
    # Sort the lists of values.  Return a sorted list of properties.
    #
    # @param [Hash{String => Array<Resource>}] properties A hash of Property to Resource mappings
    # @return [Array<String>}] Ordered list of properties.
    def order_properties(properties)
      properties.keys.each do |k|
        properties[k] = properties[k].sort do |a, b|
          a_li = a.is_a?(RDF::URI) && get_curie(a) && get_curie(a).to_s =~ /:_\d+$/ ? a.to_i : a.to_s
          b_li = b.is_a?(RDF::URI) && get_curie(b) && get_curie(b).to_s =~ /:_\d+$/ ? b.to_i : b.to_s
          
          a_li <=> b_li
        end
      end
      
      # Make sorted list of properties
      prop_list = []
      
      properties.keys.sort.each do |prop|
        prop = prop =~ /^_:(.*)$/ ? RDF::Node.intern($1) : RDF::URI.intern(prop)
        next if prop_list.include?(prop)
        prop_list << prop
      end
      
      add_debug "order_properties: #{prop_list.inspect}"
      prop_list
    end

    # Perform any statement preprocessing required. This is used to perform reference counts and determine required
    # prefixes.
    # @param [RDF::Statement] statement
    # @return [ignored]
    def preprocess_statement(statement)
      #add_debug "preprocess: #{statement.inspect}"
      references = ref_count(statement.object) + 1
      @references[statement.object] = references
      @subjects[statement.subject] = true
      get_curie(statement.subject)
      get_curie(statement.predicate)
      get_curie(statement.object)
      get_curie(statement.object.datatype) if statement.object.literal? && statement.object.has_datatype?
    end
    
    # Reset parser to run again
    def reset
      @depth = 0
      prefixes = {}
      @references = {}
      @serialized = {}
      @subjects = {}
      @top_levels = {}
    end

    protected

    # Display a subject.
    #
    # @example Displays a subject as a Resource Definition:
    #   <div typeof="rdfs:Resource" about="http://example.com/resource">
    #     <h1 property="dc:title">label</h1>
    #     <ul>
    #       <li content="2009-04-30T06:15:51Z" property="dc:created">2009-04-30T06:15:51+00:00</li>
    #     </ul>
    #   </div>
    #
    # @param [RDF::Resource] subject
    # @param [Hash{Symbol => Object}] options
    # @option options [:li, nil] :element(:div)
    #   Serialize using <li> rather than template default element
    # @option options [RDF::Resource] :rel (nil)
    #   Optional @rel property
    # @return [Nokogiri::XML::Element, {Namespace}]
    def subject(subject, options = {})
      return if is_done?(subject)
      
      subject_done(subject)
      
      properties = @graph.properties(subject)
      prop_list = order_properties(properties)
      
      # Find appropriate template
      curie ||= case
      when subject.node?
        subject.to_s if ref_count(subject) >= (@depth == 0 ? 0 : 1)
      else
        get_curie(subject)
      end

      typeof = [properties.delete(RDF.type.to_s)].flatten.compact.map {|r| get_curie(r)}.join(" ")
      typeof = nil if typeof.empty?
      
      # Nodes without a curie need a blank @typeof to generate a subject
      typeof ||= "" unless curie
      prop_list -= [RDF.type.to_s]

      add_debug "subject: #{curie.inspect}, typeof: #{typeof.inspect}, props: #{prop_list.inspect}"

      # Render this subject
      # If :rel is specified and :typeof is nil, use @resource instead of @about.
      # Pass other options from calling context
      render_opts = {:typeof => typeof}.merge(options)
      render_subject(subject, prop_list, render_opts) do |pred|
        depth do
          values = properties[pred.to_s]
          add_debug "subject: #{get_curie(subject)}, pred: #{get_curie(pred)}, values: #{values.inspect}"
          predicate(pred, values)
        end
      end
    end
    
    # Write a predicate with one or more values.
    #
    # Values may be a combination of Literal and Resource (Node or URI).
    # @param [RDF::Resource] predicate
    #   Predicate to serialize
    # @param [Array<RDF::Resource>] objects
    #   Objects to serialize
    # @return [String]
    def predicate(predicate, objects)
      add_debug "predicate: #{predicate.inspect}, objects: #{objects}"
      
      return if objects.to_a.empty?
      
      add_debug("predicate: #{get_curie(predicate)}")
      property = predicate if objects.any?(&:literal?)
      rel      = predicate if objects.any?(&:uri?) || objects.any?(&:node?)
      render_property(predicate, objects, property, rel) do |o|
        # Yields each object, for potential recursive definition.
        # If nil is returned, a leaf is produced
        depth {subject(o, :rel => rel, :element => (:li if objects.length > 1))} if !is_done?(o) && @subjects.include?(o)
      end
    end
    
    # Haml rendering helper. Return CURIE for the literal datatype, if the literal is a typed literal.
    #
    # @param [RDF::Resource] resource
    # @return [String, nil]
    # @raise [RDF::WriterError]
    def get_dt_curie(literal)
      raise RDF::WriterError, "Getting datatype CURIE for #{literal.inspect}, which must be a literal" unless literal.is_a?(RDF::Literal)
      get_curie(literal.datatype) if literal.literal? && literal.datatype?
    end

    # Haml rendering helper. Return language for plain literal, if there is no language, or it is the same as the document, return nil
    #
    # @param [RDF::Literal] literal
    # @return [String, nil]
    # @raise [RDF::WriterError]
    def get_lang(literal)
      raise RDF::WriterError, "Getting datatype CURIE for #{literal.inspect}, which must be a literal" unless literal.is_a?(RDF::Literal)
      literal.language if literal.literal? && literal.language && literal.language != @lang
    end

    # Haml rendering helper. Data to be added to a @content value
    #
    # @param [RDF::Literal] literal
    # @return [String, nil]
    # @raise [RDF::WriterError]
    def get_content(literal)
      raise RDF::WriterError, "Getting content for #{literal.inspect}, which must be a literal" unless literal.is_a?(RDF::Literal)
      case literal
      when RDF::Literal::Date, RDF::Literal::Time, RDF::Literal::DateTime
        literal.to_s
      end
    end

    # Haml rendering helper. Display value for object, may be non-canonical if get_content returns a non-nil value
    #
    # @param [RDF::Literal] literal
    # @return [String]
    # @raise [RDF::WriterError]
    def get_value(literal)
      raise RDF::WriterError, "Getting value for #{literal.inspect}, which must be a literal" unless literal.is_a?(RDF::Literal)
      case literal
      when RDF::Literal::Date
        literal.object.strftime("%A, %d %B %Y")
      when RDF::Literal::Time
        literal.object.strftime("%H:%M:%S %Z").sub(/\+00:00/, "UTC")
      when RDF::Literal::DateTime
        literal.object.strftime("%H:%M:%S %Z on %A, %d %B %Y").sub(/\+00:00/, "UTC")
      else
        literal.to_s
      end
    end

    # Haml rendering helper. Return an appropriate label for a resource.
    #
    # @param [RDF::Resource] resource
    # @return [String]
    # @raise [RDF::WriterError]
    def get_predicate_name(resource)
      raise RDF::WriterError, "Getting predicate name for #{resource.inspect}, which must be a resource" unless resource.is_a?(RDF::Resource)
      get_curie(resource)
    end

    # Haml rendering helper. Return appropriate, term, CURIE or URI for the given resource.
    #
    # @param [RDF::Value] resource
    # @return [String] value to use to identify URI
    # @raise [RDF::WriterError]
    def get_curie(resource)
      raise RDF::WriterError, "Getting CURIE for #{resource.inspect}, which must be an RDF value" unless resource.is_a?(RDF::Value)
      return resource.to_s unless resource.uri?

      @rdfcore_prefixes ||= RDF::RDFa::Profile.find(RDF::URI("http://www.w3.org/profile/rdfa-1.1")).prefixes
      
      uri = resource.to_s

      curie = case
      when @uri_to_term_or_curie.has_key?(uri)
        return @uri_to_term_or_curie[uri]
      when @base_uri && uri.index(@base_uri.to_s) == 0
        uri.sub(@base_uri.to_s, "")
      when @vocabulary && uri.index(@vocabulary) == 0
        uri.sub(@vocabulary, "")
      when u = @uri_to_prefix.keys.detect {|u| uri.index(u.to_s) == 0}
        # Use a defined prefix
        prefix = @uri_to_prefix[u]
        prefix(prefix.to_sym, u)  # Define for output
        uri.sub(u.to_s, "#{prefix}:")
      when u = @rdfcore_prefixes.values.detect {|u| uri.index(u.to_s) == 0}
        # Use standard profile prefixes
        pfx = @rdfcore_prefixes.invert[u]
        prefix(pfx, u)  # Define for output
        uri.sub(u.to_s, "#{pfx}:")
      when @options[:standard_prefixes] && vocab = RDF::Vocabulary.detect {|v| uri.index(v.to_uri.to_s) == 0}
        prefix = vocab.__name__.to_s.split('::').last.downcase
        prefix(prefix.to_sym, vocab.to_uri) # Define for output
        uri.sub(vocab.to_uri.to_s, "#{prefix}:")
      else
        uri
      end
      
      @uri_to_term_or_curie[uri] = curie
    rescue Addressable::URI::InvalidURIError => e
      raise RDF::WriterError, "Invalid URI #{uri.inspect}: #{e.message}"
    end
    private
    
    # Increase depth around a method invocation
    def depth
      @depth += 1
      ret = yield
      @depth -= 1
      ret
    end
    
    # Render HAML
    # @param [Symbol, String] template
    #   If a symbol, finds a matching template from haml_template, otherwise uses template as is
    # @param [Hash{Symbol => Object}] locals
    #   Locals to pass to render
    # @return [String]
    # @raise [RDF::WriterError]
    def hamlify(template, locals = {})
      template = haml_template[template] if template.is_a?(Symbol)

      template = template.align_left
      add_debug "hamlify template: #{template}"
      add_debug "hamlify locals: #{locals.inspect}"

      Haml::Engine.new(template, @options[:haml_options] || HAML_OPTIONS).render(self, locals) do |*args|
        yield(*args) if block_given?
      end
    rescue Haml::Error => e
      raise RDF::WriterError, "#{e.class}: #{e.message}\n" +
        "rendering #{template}\n" +
        "with options #{(@options[:haml_options] || HAML_OPTIONS).inspect}\n" +
        "and locals #{locals.inspect}"
    end

    # Mark a subject as done.
    def subject_done(subject)
      @serialized[subject] = true
    end
    
    def is_done?(subject)
      @serialized.include?(subject)
    end

    # Return the number of times this node has been referenced in the object position
    def ref_count(node)
      @references.fetch(node, 0)
    end

    # Add debug event to debug array, if specified
    #
    # @param [String] message::
    def add_debug(message)
      msg = "#{'  ' * @depth}#{message}"
      STDERR.puts msg if ::RDF::RDFa.debug?
      @debug << msg if @debug.is_a?(Array)
    end
  end
end

require 'rdf/rdfa/writer/haml_templates'
