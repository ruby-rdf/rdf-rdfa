module RDF::RDFa
  ##
  # Profile representation existing of a hash of terms, prefixes, a default vocabulary and a URI.
  #
  # Profiles are used for storing RDFa profile representations. A representation is created
  # by serializing a profile graph (typically also in RDFa, but may be in other representations).
  #
  # The class may be backed by an RDF::Repository, which will be used to retrieve a profile graph
  # or to load into, if no such graph exists
  class Profile
    # Prefix mappings defined in this profile
    # @return [Hash{Symbol => RDF::URI}]
    attr_reader :prefixes

    # Term mappings defined in this profile
    # @return [Hash{Symbol => RDF::URI}]
    attr_reader :terms
    
    # Default URI defined for this vocabulary
    # @return [RDF::URI]
    attr_reader :vocabulary

    # URI defining this profile
    # @return [RDF::URI]
    attr_reader :uri
    
    ##
    # Initialize a new profile from the given URI.
    #
    # Parses the profile and places it in the repository and cache
    #
    # @param [RDF::URI, #to_s] uri URI of profile to be represented
    def initialize(uri)
      @uri = RDF::URI.intern(uri)
      @prefixes = {}
      @terms = {}
      @vocabulary = nil
      
      Profile.load(@uri)

      resource_info = {}
      repository.query(:context => uri).each do |statement|
        res = resource_info[statement.subject] ||= {}
        next unless statement.object.is_a?(RDF::Literal)
        %w(uri term prefix vocabulary).each do |term|
          res[term] ||= statement.object.value if statement.predicate == RDF::RDFA[term]
        end
      end

      resource_info.values.each do |res|
        # If one of the objects is not a Literal or if there are additional rdfa:uri or rdfa:term
        # predicates sharing the same subject, no mapping is created.
        uri = res["uri"]
        term = res["term"]
        prefix = res["prefix"]
        vocab = res["vocabulary"]

        @vocabulary = vocab if vocab
        
        # For every extracted triple that is the common subject of an rdfa:prefix and an rdfa:uri
        # predicate, create a mapping from the object literal of the rdfa:prefix predicate to the
        # object literal of the rdfa:uri predicate. Add or update this mapping in the local list of
        # URI mappings after transforming the 'prefix' component to lower-case.
        # For every extracted
        prefix(prefix.downcase, uri) if uri && prefix && prefix != "_"
      
        # triple that is the common subject of an rdfa:term and an rdfa:uri predicate, create a
        # mapping from the object literal of the rdfa:term predicate to the object literal of the
        # rdfa:uri predicate. Add or update this mapping in the local term mappings.
        term(term, uri) if term && uri
      end
    end
    
    ##
    # @return [RDF::Util::Cache]
    # @private
    def self.cache
      require 'rdf/util/cache' unless defined?(::RDF::Util::Cache)
      @cache ||= RDF::Util::Cache.new(-1)
    end

    ##
    # Repository used for saving profiles
    # @return [RDF::Repository]
    # @raise [RDF::RDFa::ProfileError] if profile does not support contexts
    def self.repository
      @repository ||= RDF::Repository.new(:title => "RDFa Profiles")
    end
    
    ##
    # Set repository used for saving profiles
    # @param [RDF::Repository] repo
    # @return [RDF::Repository]
    def self.repository=(repo)
      raise ProfileError, "Profile Repository must support context" unless repo.supports?(:context)
      @repository = repo
    end
    
    # Return a profile faulting through the cache
    # @return [RDF::RDFa::Profile]
    def self.find(uri)
      uri = RDF::URI.intern(uri)
      
      return cache[uri] unless cache[uri].nil?
      
      # Two part creation to prevent re-entrancy problems if p1 => p2 and p2 => p1
      # Return something to make the caller happy if we're re-entered
      cache[uri] = Struct.new(:prefixes, :terms, :vocabulary).new({}, {}, nil)
      # Now do the actual load
      cache[uri] = new(uri)
    rescue Exception => e
      raise ProfileError, "Error reading profile #{uri.inspect}: #{e.message}"
    end

    # Load profile into repository
    def self.load(uri)
      uri = RDF::URI.intern(uri)
      repository.load(uri.to_s, :base_uri => uri, :context => uri) unless repository.has_context?(uri)
    end
    
    # @return [RDF::Repository]
    def repository
      Profile.repository
    end
    
    ##
    # Defines the given named URI prefix for this profile.
    #
    # @example Defining a URI prefix
    #   profile.prefix :dc, RDF::URI('http://purl.org/dc/terms/')
    #
    # @example Returning a URI prefix
    #   profile.prefix(:dc)    #=> RDF::URI('http://purl.org/dc/terms/')
    #
    # @overload prefix(name, uri)
    #   @param  [Symbol, #to_s]   name
    #   @param  [RDF::URI, #to_s] uri
    #
    # @overload prefix(name)
    #   @param  [Symbol, #to_s]   name
    #
    # @return [RDF::URI]
    def prefix(name, uri = nil)
      name = name.to_s.empty? ? nil : (name.respond_to?(:to_sym) ? name.to_sym : name.to_s.to_sym)
      uri.nil? ? prefixes[name] : prefixes[name] = uri
    end

    ##
    # Defines the given named URI term for this profile.
    #
    # @example Defining a URI term
    #   profile.term :title, RDF::URI('http://purl.org/dc/terms/title')
    #
    # @example Returning a URI profile
    #   profile.term(:title)    #=> RDF::URI('http://purl.org/dc/terms/TITLE')
    #
    # @overload term(name, uri)
    #   @param  [Symbol, #to_s]   name
    #   @param  [RDF::URI, #to_s] uri
    #
    # @overload term(name)
    #   @param  [Symbol, #to_s]   name
    #
    # @return [RDF::URI]
    def term(name, uri = nil)
      name = name.to_s.empty? ? nil : (name.respond_to?(:to_sym) ? name.to_sym : name.to_s.to_sym)
      uri.nil? ? terms[name] : terms[name] = uri
    end
  end

  ##
  # The base class for RDF profile errors.
  class ProfileError < IOError
  end # ProfileError
end