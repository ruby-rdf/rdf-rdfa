module RDFa
  ##
  # N-Triples format specification.
  #
  # @example Obtaining an NTriples format class
  #   RDF::Format.for(:ntriples)     #=> RDF::NTriples::Format
  #   RDF::Format.for("etc/doap.nt")
  #   RDF::Format.for(:file_name      => "etc/doap.nt")
  #   RDF::Format.for(:file_extension => "nt")
  #   RDF::Format.for(:content_type   => "text/plain")
  #
  # @see http://www.w3.org/TR/rdf-testcases/#ntriples
  class Format < RDF::Format
    content_type     'text/html', :extension => :html
    content_encoding 'ascii'

    reader { RDFa::Reader }
  end
end
