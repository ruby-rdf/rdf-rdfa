require 'haml'
require 'rdf/rdfa/patches/graph_properties'

module RDF::RDFa
  ##
  # An RDFa 1.1 serialiser in Ruby
  #
  # Note that the natural interface is to write a whole graph at a time.
  # Writing statements or Triples will create a graph to add them to
  # and then serialize the graph.
  #
  # The writer will add prefix definitions, and use them for creating @prefix definitions, and minting QNames
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
    # @option options [Hash<Symbol => String>] :haml (DEFAULT_HAML)
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
      doc = hamlify(:doc,
        :lang     => @lang,
        :base     => @base_uri,
        :title    => @doc_title,
        :profile  => profile,
        :prefix   => prefix,
        :subjects => subjects) do |s|
        subject(s)
      end
      @output.write(doc)
    end

    protected
    # Perform any preprocessing of statements required
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
    
    # Defines rdf:type of subjects to be emitted at the beginning of the graph. Defaults to rdfs:Class
    # @return [Array<URI>]
    def top_classes; [RDF::RDFS.Class]; end

    # Defines order of predicates to use in heading. Defaults to
    # [rdfs:label, dc:title]
    # @return [Array<URI>]
    def heading_predicates; [RDF::RDFS.label, RDF::DC.title]; end
    
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
    # @param [Statement] statement
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
    
    def reset
      @depth = 0
      prefixes = {}
      @references = {}
      @serialized = {}
      @subjects = {}
      @top_levels = {}
    end

    private

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
    # @param [Nokogiri::XML::Element] parent_node
    # @return [Nokogiri::XML::Element, {Namespace}]
    def subject(subject)
      return if is_done?(subject)
      
      subject_done(subject)
      
      properties = @graph.properties(subject)
      prop_list = order_properties(properties)
      
      curie = get_curie(subject)

      typeof = [properties.delete(RDF.type.to_s)].flatten.compact.map {|r| get_curie(r)}.join(" ")
      typeof = nil if typeof.empty?
      prop_list -= [RDF.type.to_s]

      add_debug "subject: #{curie.inspect}, typeof: #{typeof}, props: #{prop_list.inspect}"

      template_key = haml_template[:subject_template].select do |r, t|
        subject.to_s.match(r)
      end.values.first

      # Find appropriate template
      template_key ||= case
      when subject.node?
        ref_count(subject) >= (@depth == 0 ? 0 : 1) ? :node_subject : :anon_subject
      else
        :default_subject
      end

      # Render this subject
      sub = hamlify(template_key,
        :subject    => subject,
        :about      => curie,
        :typeof     => typeof,
        :predicates => prop_list) do |pred|
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
    #
    # Multi-valued properties are generated with a _ul_ and _li_. Single-valued
    # are generated with a span or anchor
    def predicate(pred, values)
      add_debug "predicate: #{pred.inspect}, values: #{values}"
      
      case (values || []).length
      when 0
        nil
      when 1
        case object = values.first
        when RDF::Node, RDF::URI
          hamlify(:single_resource, :property => get_curie(pred), :object => object) do |o|
            if is_done?(object) || !@subjects.include?(object)
              show_ref(o, get_curie(pred))
            else
              hamlify("%div{:rel => #{get_curie(pred).inspect}}\n  != yield") {depth {subject(o)}}
            end
          end
        else
          template_key = heading_predicates.include?(pred) ? :heading_literal : :single_literal
          show_lit(object, pred, template_key)
        end
      else
        property = get_curie(pred) if values.any?(&:literal?)
        rel = get_curie(pred) if values.any?(&:uri?) || values.any?(&:node?)

        add_debug("multi-value property: prop=#{property.inspect}, rel=#{rel.inspect}")

        hamlify(:multiple_resource,
          :property => property,
          :rel      => rel,
          :objects  => values) do |o|
          add_debug("val: #{o}")
          if o.literal?
            show_lit(o, pred, :_literal)
          elsif !is_done?(o) && @subjects.include?(o)
            hamlify("%li\n  != yield") {depth {subject(o)}}
          else
            hamlify("%li\n  != yield") {show_ref(o, nil)}
          end
        end
      end
    end
    
    # Increase depth around a method invocation
    def depth
      @depth += 1
      ret = yield
      @depth -= 1
      ret
    end
    
    def show_ref(object, rel)
      template_key = haml_template[:object_template].select do |r, t|
        object.to_s.match(r)
      end.values.first
      
      template_key ||= :default_resource
      curie = get_curie(object)

      hamlify(template_key, :object => object, :curie  => curie, :rel => rel)
    end
    
    def show_lit(object, predicate, template_key)
      add_debug "show_lit: #{object.inspect}, template: #{template_key.inspect}, typed: #{object.typed?.inspect}, XML: #{object.is_a?(RDF::Literal::XML)}"

      template = haml_template[template_key]
      template = haml_template[:xml_literal][template_key] if object.datatype == RDF.XMLLiteral

      property = get_curie(predicate)
      datatype = language = content = nil
      value = object.to_s

      if object.typed?
        datatype = get_curie(object.datatype)
        case object
        when RDF::Literal::Date
          content = object.to_s
          value = object.object.strftime("%A, %d %B %Y")
        when RDF::Literal::Time
          content = object.to_s
          value = object.object.strftime("%H:%M:%S %Z").sub(/\+00:00/, "UTC")
        when RDF::Literal::DateTime
          content = object.to_s
          value = object.object.strftime("%H:%M:%S %Z on %A, %d %B %Y").sub(/\+00:00/, "UTC")
        end
      else
        language = object.language.to_sym if object.language && object.language.to_sym != @options[:lang]
        STDERR.puts("lit lang: #{language.inspect}, base #{@options[:lang].inspect}") if language
      end

      #add_debug "show_lit key: #{template_key}, template: #{template}"
      hamlify(template,
        :depth    => (@depth / 2), 
        :property => property,
        :datatype => datatype,
        :lang     => language,
        :content  => content,
        :value    => value)
    end
    
    # Render HAML
    # @param [Symbol, String] template
    #   If a symbol, finds a matching template from haml_template, otherwise uses template as is
    # @param [Hash{Symbol => Object}] locals
    #   Locals to pass to render
    # @return [String]
    def hamlify(template, locals = {})
      template = haml_template[template] if template.is_a?(Symbol)

      Haml::Engine.new(template, @options[:haml_options] || HAML_OPTIONS).render(Object.new, locals) do |*args|
        yield(*args) if block_given?
      end
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

    # Return appropriate, term, curie or URI for the given uri
    # @param [RDF::Resource] resource
    # @return [String] value to use to identify URI
    def get_curie(resource)
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
  end
end

require 'rdf/rdfa/writer/haml_templates'
