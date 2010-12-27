require 'nokogiri'  # FIXME: Implement using different modules as in RDF::TriX
require 'rdf/rdfxml/patches/graph_properties'

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
    # @option options [Boolean]  :use_datatypes (true)
    #   Generate literals with an @datatype, otherwise they're output as untyped literals
    # @option options [Hash]     :prefixes     (Hash.new)
    #   the prefix mappings to use
    # @option options [#to_a]     :profiles     (Array.new)
    #   List of profiles to add to document. This will use terms, prefix definitions and default-vocabularies
    #   identified within the profiles (taken in reverse order) to determine how to serialize terms
    # @option options [#to_s]    :base_uri     (nil)
    #   the base URI to use when constructing relative URIs, set as html>head>base.href
    # @option options [#to_s]   :lang   (nil)
    #   Output as root xml:lang attribute, and avoid generation _xml:lang_ where possible
    # @option options [Boolean]  :standard_prefixes   (false)
    #   Add standard prefixes to _prefixes_, if necessary.
    # @option options [Repository] :profile_repository (nil)
    #   Repository to find and save profile graphs.
    # @yield  [writer]
    # @yieldparam [RDF::Writer] writer
    def initialize(output = $stdout, options = {}, &block)
      super do
        @uri_to_term_or_curie = {}
        @uri_to_prefix = {}
        @graph = RDF::Graph.new
        raise ReaderError, "Profile Repository must support context" unless @profile_repository.supports?(:context)

        block.call(self) if block_given?
      end
      self.profile_repository = options[:profile_repository] if options[:profile_repository]
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

      doc = Nokogiri::XML::Document.new

      add_debug "\nserialize: graph: #{@graph.size}"

      preprocess

      add_debug "\nserialize: graph namespaces: #{prefixes.inspect}"

      doc.root = Nokogiri::XML::Element.new("html", doc)
      doc.root.default_namespace = "http://www.w3.org/1999/xhtml"
      doc.root["xml:lang"] = @lang.to_s.downcase if @lang

      head = Nokogiri::XML::Element.new("head", doc)
      doc.root.add_child(head)

      # Base
      if @base_uri
        base = Nokogiri::XML::Element.new("base", doc)
        base["href"] = @base_uri
        head.add_child(base)
      end

      body = Nokogiri::XML::Element.new("body", doc)
      doc.root.add_child(body)
      
      # Determine prefixes that need to be generated by removing those defined
      # within profiles

      # Profile and Prefixes
      if prefixes = @options[:prefixes]
        html["prefix"] = prefixes.keys.sort.map {|pk| "#{pk}: #{profiles[p_k]}"}.join(" ")
      end

      if profiles = @options[:profiles]
        doc.root["profile"] = profiles.join(" ")
      end

      # Add statements for each subject
      order_subjects.each do |subject|
        #add_debug "subj: #{subject.inspect}"
        subject(subject, body)
      end

      prefixes.each_pair do |p, uri|
        if p == nil
          doc.root.default_namespace = uri.to_s
        else
          doc.root.add_namespace(p.to_s, uri.to_s)
        end
      end

      doc.write_xml_to(@output, :encoding => "UTF-8", :indent => 2)
    end

    protected
    # Perform any preprocessing of statements required
    def preprocess
      # Load profiles
      # Add terms and prefixes to local store for converting URIs
      # Keep track of vocabulary from left-most profile
      [@options[:profiles]].flatten.reverse.each do |uri|
        prof = Profile.find(uri)
        prof.prefixes.each_pair do |k, v|
          @uri_to_prefix[v] = k
        end
        
        prof.terms.each_pair do |k, v|
          @uri_to_term_or_curie[v] = k
        end
        
        @vocabulary = prof.vocabulary.to_s
      end
      
      # Load defined prefixes
      (@options[:prefixes] || {}).each_pair do |k, v|
        @uri_to_prefix[RDF::URI.intern(v)] = k
      end
      
      # Process each statement to establish CURIEs and Terms
      @graph.each {|statement| preprocess_statement(statement)}
    end
    
    # Defines rdf:type of subjects to be emitted at the beginning of the graph. Defaults to rdfs:Class
    # @return [Array<URI>]
    def top_classes; [RDF::RDFS.Class]; end

    # Defines order of predicates to use in heading. Defaults to
    # [rdfs:label, dc:title]
    # @return [Array<URI>]
    def heading_predicates; [RDF.type, RDF::RDFS.label, RDF::DC.title]; end
    
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
      
      # Sort subjects by resources over bnodes, ref_counts and the subject URI itself
      recursable = @subjects.keys.
        select {|s| !seen.include?(s)}.
        map {|r| [r.is_a?(RDF::Node) ? 1 : 0, ref_count(r), r]}.
        sort
      
      subjects += recursable.map{|r| r.last}
    end
    
    # Take a hash from predicate uris to lists of values.
    # Sort the lists of values.  Return a sorted list of properties.
    # @param [Hash{String => Array<Resource>}] properties A hash of Property to Resource mappings
    # @return [Array<String>}] Ordered list of properties. Uses predicate_order.
    def order_properties(properties)
      properties.keys.each do |k|
        properties[k] = properties[k].sort do |a, b|
          a_li = a.is_a?(RDF::URI) && get_curie(a) && get_curie(a).last.to_s =~ /^_\d+$/ ? a.to_i : a.to_s
          b_li = b.is_a?(RDF::URI) && get_curie(b) && get_curie(b).last.to_s =~ /^_\d+$/ ? b.to_i : b.to_s
          
          a_li <=> b_li
        end
      end
      
      # Make sorted list of properties
      prop_list = []
      
      predicate_order.each do |prop|
        next unless properties[prop]
        prop_list << prop.to_s
      end
      
      properties.keys.sort.each do |prop|
        next if prop_list.include?(prop.to_s)
        prop_list << prop.to_s
      end
      
      add_debug "sort_properties: #{prop_list.to_sentence}"
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
    # @example
    # Displays a subject as a Resource Definition:
    #   <div typeof="rdfs:Resource" about="http://example.com/resource">
    #     <h1 property="dc:title">label</h1>
    #     <ul>
    #       <li content="2009-04-30T06:15:51Z" property="dc:created">2009-04-30T06:15:51+00:00</li>
    #     </ul>
    #   </div>
    #
    # @param [RDF::Resource] subject
    # @param [Nokogiri::XML::Element] parent_node
    # @param [Hash] options ({})
    # @option options [String] :div ("div") Element name, defaults to "div"
    # @return [Nokogiri::XML::Element, {Namespace}]
    def subject(subject, parent_node, options = {})
      return if is_done?(subject)
      
      options[:div] ||= "div"

      subject_done(subject)
      
      resource_uri = get_curie(subject) unless subject.is_a?(BNode) && ref_count(subject) == 1
      
      properties = @graph.properties(subject)
      prop_list = order_properties(properties)
      add_debug "subject: #{subject.inspect}, props: #{properties.inspect}"
      
      typeof = [prop_list.delete(RDF.type.to_s)].flatten.compact.map {|r| get_curie(r)}.join(" ")

      node = Nokogiri::XML::Element.new(options[:div], parent_node.document)
      node["about"] = resource_uri if resource_uri
      node["typeof"] = typeof if typeof.length > 0
      add_debug "subject: #{subject.inspect }, about: #{resource_uri}, typeof: #{typeof}" if $CMX_DEBUG

      # Output properties as unordered list
      prop_nodes = []
      @depth += 1
      prop_list.each_pair do |pred, values|
        if heading_predicates.include?(pred)
          # Add heading-type nodes
          values.each do |v|
            h = Nokogiri::XML::Element.new("h#{@depth}", parent_node.document)
            h["property"] = v
            node.add_child(h)
          end
        else
          predicate(pred, values, node, options.merge(:div => "li"))
        end
      end
      @depth -= 1

      parent_node.add_child(node)
    end
    
    def predicate(pred, values, parent_node, options)
      add_debug "predicate: #{pred.inspect}, values: #{values}"
      next if values.empty?
      
      # Split values into literals and others
      literals = values.select {|r| r.literal? }
      resources = values - literals
      
      
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
      @debug << message if @debug.is_a?(Array)
    end

    # Return appropriate, term, curie or URI for the given uri
    # @param [URI,#to_s] uri
    # @return [String] value to use to identify URI
    def get_curie(uri)
      uri_s = uri.to_s
      uri = RDF::URI.intern(uri)
      return @uri_to_term_or_curie[uri] if @uri_to_term_or_curie.has_key?(uri)
      
      return uri.to_s if uri.is_a?(RDF::Node)
      
      # Use @base_uri
      if @base_uri && uri_s.index(@base_uri.to_s) == 0
        return @uri_to_term_or_curie[uri] = uri_s.sub(@base_uri.to_s, "")
      end
      
      # Use default vocabulary
      if @vocabulary && uri_s.index(@vocabulary) == 0
        return @uri_to_term_or_curie[uri] = uri_s.sub(@vocabulary, "")
      end
      
      # Use a defined prefix
      @uri_to_prefix.keys.each do |u|
        if uri_s.index(u.to_s) == 0
          prefix = @uri_to_prefix[u]
          return @uri_to_term_or_curie[uri] = uri_s.sub(u.to_s, "#{prefix}:")
        end
      end
      
      # Use a standard prefix
      if @options[:standard_prefixes] && vocab = RDF::Vocabulary.detect {|v| uri_s.index(v.to_uri.to_s) == 0}
        prefix = vocab.__name__.to_s.split('::').last.downcase
        prefix(prefix.to_sym, vocab.to_uri)
        return @uri_to_term_or_curie[uri] = uri_s.sub(vocab.to_uri.to_s, "#{prefix}:")
      end
      
      # Just use the URI
      @uri_to_term_or_curie[uri] = uri.to_s
    end
  end
end