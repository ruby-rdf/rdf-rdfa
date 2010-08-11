module RDF
  class URI
    ##
    # Joins several URIs together.
    #
    # @param  [Array<String, URI, #to_str>] uris
    # @return [URI]
    #
    # GK -- don't add a "/" at the end of URIs, due to rdfcore/xmlbase/test002.rdf
    def join(*uris)
      result = @uri
      uris.each do |uri|
        result = result.join(uri)
      end
      self.class.new(result)
    end
  
  class NTriples::Writer
    def format_uri(uri, options = {})
      "<%s>" % escaped(uri_for(uri))
    end
  end
  end
end