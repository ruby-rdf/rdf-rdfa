module RDF::RDFa
  ##
  # RDFa format specification.
  #
  # @example Obtaining an RDFa format class
  #   RDF::Format.for(:rdfa)     #=> RDF::RDFa::Format
  #   RDF::Format.for("etc/doap.html")
  #   RDF::Format.for(:file_name      => "etc/doap.html")
  #   RDF::Format.for(:file_extension => "html")
  #   RDF::Format.for(:content_type   => "text/html")
  #   RDF::Format.for(:content_type   => "application/xhtml+xml")
  #
  # @example Obtaining serialization format MIME types
  #   RDF::Format.content_types      #=> {"text/html" => [RDF::RDFa::Format]}
  #
  # @example Obtaining serialization format file extension mappings
  #   RDF::Format.file_extensions    #=> {:xhtml => "application/xhtml+xml"}
  #
  # @see http://www.w3.org/TR/rdf-testcases/#ntriples
  class Format < RDF::Format
    content_encoding 'utf-8'
    content_type     'text/html', :extension => :html
    reader { RDF::RDFa::Reader }
    writer { RDF::RDFa::Writer }

    ##
    # Sample detection to see if it matches RDFa (not RDF/XML or Microdata)
    #
    # Use a text sample to detect the format of an input file. Sub-classes implement
    # a matcher sufficient to detect probably format matches, including disambiguating
    # between other similar formats.
    #
    # @param [String] sample Beginning several bytes (~ 1K) of input.
    # @return [Boolean]
    def self.detect(sample)
      (sample.match(/<[^>]*(about|resource|prefix|typeof|property|vocab)\s*="[^>]*>/m) ||
       sample.match(/<[^>]*DOCTYPE\s+html[^>]*>.*xmlns:/im)
      ) && !sample.match(/<(\w+:)?(RDF)/)
    end
  end

  # Aliases for RDFa::Format
  #
  # This allows the following:
  #
  # @example Obtaining an HTML format class
  #   RDF::Format.for(:lite)         # RDF::RDFa::Lite
  #   RDF::Format.for(:lite).reader  # RDF::RDFa::Reader
  #   RDF::Format.for(:lite).writer  # RDF::RDFa::Writer
  class Lite < RDF::Format
    content_encoding 'utf-8'
    content_type     'text/html', :extension => :html
    reader { RDF::RDFa::Reader }
    writer { RDF::RDFa::Writer }
  end

  # Aliases for RDFa::Format
  #
  # This allows the following:
  #
  # @example Obtaining an HTML format class
  #   RDF::Format.for(:html)         # RDF::RDFa::HTML
  #   RDF::Format.for(:html).reader  # RDF::RDFa::Reader
  #   RDF::Format.for(:html).writer  # RDF::RDFa::Writer
  class HTML < RDF::Format
    content_encoding 'utf-8'
    content_type     'text/html', :extension => :html
    reader { RDF::RDFa::Reader }
    writer { RDF::RDFa::Writer }
  end

  # Aliases for RDFa::Format
  #
  # This allows the following:
  #
  # @example Obtaining an HTML format class
  #   RDF::Format.for(:xhtml)         # RDF::RDFa::XHTML
  #   RDF::Format.for(:xhtml).reader  # RDF::RDFa::Reader
  #   RDF::Format.for(:xhtml).writer  # RDF::RDFa::Writer
  class XHTML < RDF::Format
    content_encoding 'utf-8'
    content_type     'application/xhtml+xml', :extension => :xhtml
    reader { RDF::RDFa::Reader }
    writer { RDF::RDFa::Writer }
  end

  # Aliases for RDFa::Format
  #
  # This allows the following:
  #
  # @example Obtaining an HTML format class
  #   RDF::Format.for(:svg)         # RDF::RDFa::SVG
  #   RDF::Format.for(:svg).reader  # RDF::RDFa::Reader
  #   RDF::Format.for(:svg).writer  # RDF::RDFa::Writer
  class SVG < RDF::Format
    content_encoding 'utf-8'
    content_type     'image/svg+xml', :extension => :svg
    reader { RDF::RDFa::Reader }
    writer { RDF::RDFa::Writer }
  end
end
