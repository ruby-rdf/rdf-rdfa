module RDF::RDFa
  ##
  # The Expansion module performs a subset of OWL entailment rules on the base class,
  # which implementes RDF::Readable.
  module Expansion
    ##
    # Pre-processed vocabularies used to simplify loading of common vocabularies
    COOKED_VOCAB_STATEMENTS = []

    ##
    # Perform vocabulary expansion on the resulting default graph.
    #
    #   Vocabulary expansion relies on a sub-set of OWL [OWL2-PROFILES] entailment to add
    #   triples to the default graph based on rules and property/class relationships
    #   described in referenced vocabularies.
    #
    # For all objects that are the target of an rdfa:usesVocabulary property, load the IRI into
    # a repository.
    #
    # Subsequently, perform OWL expansion using rules prp-spo1, prp-eqp1,
    # prp-eqp2, cax-sco, cax-eqc1, and cax-eqc2 placing resulting triples into the default
    # graph. Iterate on this step until no more triples are added.
    #
    # @example
    #    scm-spo
    #    {pq rdfs:subPropertyOf pw . pw rdfs:subPropertyOf p3} => {p1 rdfs:subPropertyOf p3}
    #
    #    rdprp-spo1fs7
    #    {p1 rdfs:subPropertyOf p2 . x p1 y} => {x p2 y}
    #
    #    cax-sco
    #    {c1 rdfs:subClassOf c2 . x rdf:type c1} => {x rdf:type c2}
    #
    #    scm-sco
    #    {c1 rdfs:subClassOf c2 . c2 rdfs:subClassOf c3} => {c1 rdfs:subClassOf c3}
    #
    # @return [RDF::Graph]
    # @see [OWL2 PROFILES](http://www.w3.org/TR/2009/REC-owl2-profiles-20091027/#Reasoning_in_OWL_2_RL_and_RDF_Graphs_using_Rules)
    def expand
      repo = RDF::Repository.new
      repo << self  # Add default graph
      
      count = repo.count
      add_debug("expand") {"Loaded #{repo.size} triples into default graph"}
      
      # Vocabularies managed in vocab_repo, and copied to repo for processing.
      # This allows for persistent storage of vocabularies
      @@vocab_repo = @options[:vocab_repository] if @options.has_key?(:vocab_repository)
      @@vocab_repo ||= RDF::Repository.new.insert(*COOKED_VOCAB_STATEMENTS)
      
      vocabs = repo.query(:predicate => RDF::RDFA.usesVocabulary).to_a.map(&:object)
      vocabs.each do |vocab|
        begin
          unless @@vocab_repo.has_context?(vocab)
            add_debug("expand", "Load #{vocab}")
            @@vocab_repo.load(vocab, :context => vocab)
          end
        rescue Exception => e
          # XXX: update spec to indicate the error if the vocabulary fails to laod
          add_warning("expand", "Error loading vocabulary #{vocab}: #{e.message}", RDF::RDFA.UnresovedVocabulary)
        end
      end
      
      @@vocab_repo.each do |statement|
        if vocabs.include?(statement.context)
          repo << statement
        end
      end
      
      if repo.count == count
        add_debug("expand", "No vocabularies loaded")
      else
        repo = owl_entailment(repo)
      end

      # Return graph with default context
      graph = RDF::Graph.new
      repo.statements.each {|st| graph << st if st.context.nil?}
      graph
    end

    def rule(name, &block)
      Rule.new(name, block)
    end

    ##
    # An entailment rule
    #
    # Takes a list of antecedent patterns used to find solutions against a queryable
    # object. Yields each consequent with bindings from the solution
    class Rule
      # @attr [Array<RDF::Query::Pattern>]
      attr_reader :antecedents

      # @attr [Array<RDF::Query::Pattern>]
      attr_reader :consequents

      # @attr [String] name
      attr_reader :name

      ##
      # @example
      #   r = Rule.new("scm-spo") do
      #     antecedent :p1, RDF::RDFS.subPropertyOf, :p2
      #     antecedent :p2, RDF::RDFS.subPropertyOf, :p3
      #     consequent :p1, RDF::RDFS.subPropertyOf, :p3, "t-box"
      #   end
      #
      #   r.execute(queryable) {|statement| puts statement.inspect}
      #
      # @param [String] name
      def initialize(name, &block)
        @antecedents = []
        @consequents = []
        @name = name

        if block_given?
          case block.arity
            when 1 then block.call(self)
            else instance_eval(&block)
          end
        end
      end

      def antecedent(subject, prediate, object, context = nil)
        antecedents << RDF::Query::Pattern.new(subject, prediate, object, :context => context)
      end

      def consequent(subject, prediate, object, context = nil)
        consequents << RDF::Query::Pattern.new(subject, prediate, object, :context => context)
      end
      
      ##
      # Execute the rule against queryable, yielding each consequent with bindings
      #
      # @param [RDF::Queryable] queryable
      # @yield [statement]
      # @yieldparam [RDF::Statement] statement
      def execute(queryable)
        RDF::Query.new(antecedents).execute(queryable).each do |solution|
          nodes = {}
          consequents.each do |consequent|
            terms = {}
            [:subject, :predicate, :object, :context].each do |r|
              terms[r] = case o = consequent.send(r)
              when RDF::Node            then nodes[o] ||= RDF::Node.new
              when RDF::Query::Variable then solution[o]
              else                           o
              end
            end

            yield RDF::Statement.from(terms)
          end
        end
      end
    end

  private

    RULES = [
      Rule.new("prp-spo1") do
        antecedent :p1, RDF::RDFS.subPropertyOf, :p2
        antecedent :x, :p1, :y
        consequent :x, :p2, :y
      end,
      Rule.new("prp-eqp1") do
        antecedent :p1, RDF::OWL.equivalentProperty, :p2
        antecedent :x, :p1, :y
        consequent :x, :p2, :y
      end,
      Rule.new("prp-eqp2") do
        antecedent :p1, RDF::OWL.equivalentProperty, :p2
        antecedent :x, :p2, :y
        consequent :x, :p1, :y
      end,
      Rule.new("cax-sco") do
        antecedent :c1, RDF::RDFS.subClassOf, :c2
        antecedent :x, RDF.type, :c1
        consequent :x, RDF.type, :c2
      end,
      Rule.new("cax-eqc1") do
        antecedent :c1, RDF::OWL.equivalentClass, :c2
        antecedent :x, RDF.type, :c1
        consequent :x, RDF.type, :c2
      end,
      Rule.new("cax-eqc2") do
        antecedent :c1, RDF::OWL.equivalentClass, :c2
        antecedent :x, RDF.type, :c2
        consequent :x, RDF.type, :c1
      end,
    ]

    ##
    # Perform OWL entailment rules on repository
    # @param [RDF::Repository] repo
    # @return [RDF::Repository]
    def owl_entailment(repo)
      old_count = 0

      while old_count < (count = repo.count)
        add_debug("entailment", "old: #{old_count} count: #{count}")
        old_count = count

        RULES.each do |rule|
          rule.execute(repo) do |statement|
            add_debug("entailment(#{rule.name})") {statement.inspect}
            repo << statement
          end
        end
      end
      
      add_debug("entailment", "final count: #{count}")
      repo
    end
  end
end

# Load cooked vocabularies
Dir.glob(File.join(File.expand_path(File.dirname(__FILE__)), 'expansion', '*')).each {|f| load f}
