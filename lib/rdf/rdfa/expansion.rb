require 'rdf/reasoner'

module RDF::RDFa
  ##
  # The Expansion module performs a subset of OWL entailment rules on the base class,
  # which implementes RDF::Readable.
  module Expansion

    ##
    # Perform vocabulary expansion on the resulting default graph.
    #
    #   Vocabulary expansion uses the built-in reasoner using included vocabularies from RDF.rb.
    #
    # @param [RDF::Repository] repository
    # @see [OWL2 PROFILES](http://www.w3.org/TR/2009/REC-owl2-profiles-20091027/#Reasoning_in_OWL_2_RL_and_RDF_Graphs_using_Rules)
    def expand(repository)
      count = repository.count
      add_debug("expand") {"Repository has #{repository.size} statements"}
      
      RDF::Reasoner.apply(:rdfs, :owl)
      repository.entail!
      add_debug("expand") {"Repository now has #{repository.size} statements"}

    end

    ##
    # Perform property copying on the resulting default graph.
    #
    # For all objects of type rdfa:Pattern that are the target of an rdfa:copy property, load the IRI into a repository.
    #
    # Subsequently, remove reference rdfa:Pattern objects.
    #
    # @param [RDF::Repository] repository
    # @see [HTML+RDFa](http://www.w3.org/TR/rdfa-in-html/#rdfa-reference-folding)
    def copy_properties(repository)
      add_debug("expand") {"Repository has #{repository.size} statements"}
      fold(repository)
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
      # @!attribute [r] antecedents
      # @return [Array<RDF::Query::Pattern>]
      attr_reader :antecedents

      # @!attribute [r] consequents
      # @return [Array<RDF::Query::Pattern>]
      attr_reader :consequents

      # @!attribute [r] deletions
      # @return [Array<RDF::Query::Pattern>]
      attr_reader :deletions

      # @!attribute [r] name
      # @return [String]
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

    FOLDING_RULES = [
      Rule.new("rdfa-ref") do
        antecedent :x, RDF::RDFA.copy, :PR
        antecedent :PR, RDF.type, RDF::RDFA.Pattern
        antecedent :PR, :p, :y
        consequent :x, :p, :y
      end,
    ]

    REMOVAL_RULES = [
      Rule.new("rdfa-ref-remove") do
        antecedent :x, RDF::RDFA.copy, :PR
        antecedent :PR, RDF.type, RDF::RDFA.Pattern
        antecedent :PR, :p, :y
        consequent :x, RDF::RDFA.copy, :PR
        consequent :x, RDF.type, RDF::RDFA.Pattern
        consequent :PR, :p, :y
      end,
    ]

    ##
    # Perform RDFa folding rules on repository
    # @param [RDF::Repository] repository
    def fold(repository)
      old_count = 0

      # Continue as long as new statements are added to repository
      while old_count < (count = repository.count)
        #add_debug("fold") {"old: #{old_count} count: #{count}"}
        old_count = count
        to_add = []

        FOLDING_RULES.each do |rule|
          rule.execute(repository) do |statement|
            #add_debug("fold(#{rule.name})") {statement.inspect}
            to_add << statement
          end
        end
        
        repository.insert(*to_add)
      end

      # Remove statements matched by removal rules
      to_remove = []
      REMOVAL_RULES.each do |rule|
        rule.execute(repository) do |statement|
          #add_debug("removal(#{rule.name})") {statement.inspect}
          to_remove << statement
        end
      end
      repository.delete(*to_remove)

      add_debug("fold", "final count: #{count}")
    end
  end
end
