module RdfContext
  class RdfException    < RuntimeError; end

  class ParserException < RdfException; end
  class SparqlException < RdfException; end
  class GraphException  < RdfException; end
  class StoreException  < RdfException; end
  class BNodeException  < RdfException; end
  class TypeError       < RdfException; end
  class InvalidNode     < RdfException; end
  class InvalidPredicate < RdfException; end

  class ReadOnlyGraphException < GraphException; end
end