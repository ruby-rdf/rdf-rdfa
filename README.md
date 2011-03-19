# RDF::RDFa reader/writer

[RDFa][RDFa 1.1 Core] parser for RDF.rb.

## DESCRIPTION
RDF::RDFa is an RDFa reader and writer for Ruby using the [RDF.rb][RDF.rb] library suite.

## FEATURES
RDF::RDFa parses [RDFa][RDFa 1.1 Core] into statements or triples.

* Fully compliant RDFa 1.1 parser.
* Writer to generate generic XHTML+RDFa.
* Uses Nokogiri for parsing HTML/SVG
* [RDFa tests][RDFa-test-suite] use SPARQL for most tests due to Rasqal limitations. Other tests compare directly against N-triples.

Install with 'gem install rdf-rdfa'

## Usage

### Reading RDF data in the XHTML+RDFa format

    RDF::RDFa::Reader.open("etc/foaf.html") do |reader|
      reader.each_statement do |statement|
        puts statement.inspect
      end
    end

### Writing RDF data using the XHTML+RDFa format

    require 'rdf/rdfa'
    
    RDF::RDFa::Writer.open("hello.html") do |writer|
      writer << RDF::Graph.new do |graph|
        graph << [:hello, RDF::DC.title, "Hello, world!"]
      end
    end

## Dependencies
* [RDF.rb](http://rubygems.org/gems/rdf) (>= 0.3.1)
* [Nokogiri](http://rubygems.org/gems/nokogiri) (>= 1.3.3)

## Documentation
Full documentation available on [RubyForge](http://rdf.rubyforge.org/rdfa)

### Principle Classes
* {RDF::RDFa::Format}
* {RDF::RDFa::Reader}
* {RDF::RDFa::Profile}

### Additional vocabularies
* {RDF::PTR}
* {RDF::RDFA}
* {RDF::XHV}
* {RDF::XML}
* {RDF::XSI}

## TODO
* Add support for LibXML and REXML bindings, and use the best available
* Consider a SAX-based parser for improved performance
* Port SPARQL tests to native SPARQL processor, when released.

## Resources
* [RDF.rb][RDF.rb]
* [Distiller](http://distiller.kellogg-assoc)
* [Documentation](http://rdf.rubyforge.org/rdfa)
* [History](file:file.History.html)
* [RDFa 1.1 Core][RDFa 1.1 Core]
* [XHTML+RDFa 1.1][XHTML+RDFa 1.1]
* [RDFa-test-suite](http://rdfa.digitalbazaar.com/test-suite/              "RDFa test suite")

## AUTHOR
* [Gregg Kellogg](http://github.com/gkellogg) - <http://kellogg-assoc.com/>

## CONTRIBUTORS
* [Nicholas Humfrey](http://github.com/njh)

## License

This is free and unencumbered public domain software. For more information,
see <http://unlicense.org/> or the accompanying {file:UNLICENSE} file.

## FEEDBACK

* gregg@kellogg-assoc.com
* <http://rubygems.org/rdf-rdfa>
* <http://github.com/gkellogg/rdf-rdfa>
* <http://lists.w3.org/Archives/Public/public-rdf-ruby/>

[RDF.rb]:           http://rdf.rubyforge.org/
[RDFa 1.1 Core]:    http://www.w3.org/TR/2010/WD-rdfa-core-20100422/     "RDFa 1.1 Core"
[XHTML+RDFa 1.1]:   http://www.w3.org/TR/2010/WD-xhtml-rdfa-20100422/   "XHTML+RDFa 1.1"
[RDFa-test-suite]:  http://rdfa.digitalbazaar.com/test-suite/           "RDFa test suite"
