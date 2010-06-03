$:.unshift(File.dirname(__FILE__)) unless $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
require 'rdf'

module RDF
  ##
  # **`RDF::RDFa`** is an RDFa plugin for RDF.rb.
  #
  # @example Requiring the `RDF::RDFa` module
  #   require 'rdf/rdfa'
  #
  # @example Parsing RDF statements from an XHTML+RDFa file
  #   RDF::RDFa::Reader.open("etc/foaf.html") do |reader|
  #     reader.each_statement do |statement|
  #       puts statement.inspect
  #     end
  #   end
  #
  # @example Serializing RDF statements into a XHTML+RDFa file
  #   RDF::RDFa::Writer.open("etc/test.xml") do |writer|
  #     reader.each_statement do |statement|
  #       writer << statement
  #     end
  #   end
  #
  # @see http://rdf.rubyforge.org/
  # @see http://www.w3.org/TR/xhtml-rdfa-primer/
  # @see http://www.w3.org/2010/02/rdfa/wiki/Main_Page
  # @see http://www.w3.org/TR/2010/WD-rdfa-core-20100422/
  # @see http://www.w3.org/TR/2010/WD-xhtml-rdfa-20100422/
  #
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  module RDFa
    require 'rdfa/format'
    autoload :Reader,  'rdf/rdfa/reader'
    autoload :Writer,  'rdf/rdfa/writer'
    autoload :VERSION, 'rdf/rdfa/version'
  end
end\
