module RDF::RDFa
  ##
  # The Expansion module performs a subset of RDFS entailment rules on the base class,
  # which implementes RDF::Readable.
  module Expansion
    ##
    # Perform vocabulary expansion on the resulting default graph.
    #
    #   Vocabulary expansion relies on a sub-set of RDFS [RDF-SCHEMA] entailment to add triples to the default graph
    #   based on rules and property/class relationships described in referenced vocabularies.
    #
    # For all objects that are the target of an rdfa:hasVocabulary property, load the IRI into
    # a repository.
    #
    # Subsequently, perform RDFS expansion using rules rdfs5, rdfs7, rdfs9, and rdfs11 placing
    # resulting triples into the default graph. Iterate on this step until no more triples are added.
    #
    #    rdfs5
    #    {uuu rdfs:subPropertyOf vvv . vvv rdfs:subPropertyOf xxx} => { uuu rdfs:subPropertyOf xxx}
    #
    #    rdfs7
    #    {aaa rdfs:subPropertyOf bbb . uuu aaa yyy} => { uuu bbb yyy}
    #
    #    rdfs9
    #    {uuu rdfs:subClassOf xxx . vvv rdf:type uuu} => { vvv rdf:type xxx}
    #
    #    rdfs11
    #    {uuu rdfs:subClassOf vvv . vvv rdfs:subClassOf xxx} => { uuu rdfs:subClassOf xxx}
    #
    # @return [RDF::Graph]
    def expand
      repo = RDF::Repository.new
      repo << self  # Add default graph
      
      count = repo.count
      
      add_debug("expand", "Loaded #{repo.size} triples into default graph")
      repo.query(:predicate => RDF::RDFA.hasVocabulary).to_a.map(&:object).each do |vocab|
        begin
          add_debug("expand", "Load #{vocab}")
          repo.load(vocab, :context => vocab)
        rescue RDF::FormatError => e
          # XXX: update spec to indicate the error if the vocabulary fails to laod
          add_error("expand", "Error loading vocabulary #{vocab}: #{e.message}", RDF::RDFA.VocabularyReferenceError)
        end
      end
      
      if repo.count == count
        add_debug("expand", "No vocabularies loaded")
      else
        repo = rdfs_entailment(repo)
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
      #   r = Rule.new("rdfs5") do
      #     antecedent :uuu, RDF::RDFS.subPropertyOf, :vvv
      #     antecedent :vvv, RDF::RDFS.subPropertyOf, :xxx
      #     consequent :uuu, RDF::RDFS.subPropertyOf, :xxx, "t-box"
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
      Rule.new("rdfs5") do
        antecedent :uuu, RDF::RDFS.subPropertyOf, :vvv
        antecedent :vvv, RDF::RDFS.subPropertyOf, :xxx
        consequent :uuu, RDF::RDFS.subPropertyOf, :xxx, "t-box"
      end,
      Rule.new("rdfs7") do
        antecedent :aaa, RDF::RDFS.subPropertyOf, :bbb
        antecedent :uuu, :aaa, :yyy
        consequent :uuu, :bbb, :yyy
      end,
      Rule.new("rdfs9") do
        antecedent :uuu, RDF::RDFS.subClassOf, :xxx
        antecedent :vvv, RDF.type, :uuu
        consequent :vvv, RDF.type, :xxx
      end,
      Rule.new("rdfs11") do
        antecedent :uuu, RDF::RDFS.subClassOf, :vvv
        antecedent :vvv, RDF::RDFS.subClassOf, :xxx
        consequent :uuu, RDF::RDFS.subClassOf, :xxx, "t-box"
      end
    ]

    ##
    # Perform RDFS entailment rules on repository
    # @param [RDF::Repository] repo
    # @return [RDF::Repository]
    def rdfs_entailment(repo)
      old_count = 0

      while old_count < (count = repo.count)
        add_debug("entailment", "old: #{old_count} count: #{count}")
        old_count = count

        RULES.each do |rule|
          rule.execute(repo) do |statement|
            add_debug("entailment(#{rule.name})", statement.inspect)
            repo << statement
          end
        end
      end
      
      add_debug("entailment", "final count: #{count}")
      repo
    end
  end
end
