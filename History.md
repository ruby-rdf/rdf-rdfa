### 0.3.4.1
* Change built-in profiles to use alias\_method\_chain, as they were being removed from the cache.
* Fixes to Writer template detection with type.

### 0.3.4
* Add writer support for template selection based on subject type.

### 0.3.3.3
* Minor update to rdfa-1-1 profile

### 0.3.3.2
* In Reader:
  * Ensure that encoding is set to utf-8 if not specified.
  * Look for encoding from input and HTML meta tags.
  * Look for content-type from input and HTML meta tags.
  * Retrieve @xmlns, @xml:lang and @lang as attributes when doing HTML parsing.

### 0.3.3.1
* Improve format detection.
* Use HTML parser instead of XML if format is determined to be html4 or html5.

### 0.3.3
* Major update to writer using Haml templates, rather than Nokogiri node creation.

### 0.3.2
* Added RDFa Writer, to perform templated serialization of RDF content to RDFa.
  * Uses Haml to define default and minimal templates for RDFa serialization.
  * Allows templates to be specified on invocation, for arbitrary RDFa serialization.
* Update to pre-LC2 drafts of RDFa
* Add support for cached profiles, and include cached profiles for XML+RDFa and XHTML+RDFa.
  * Profiles are processed left to right
  * Detect 1.0 using @version
  * Automatically load profiles based on host language

### 0.3.1.2
* Assert :html and xhtml as a format types (by creating RDF::RDFa::HTML/XHTML as a sub-class of Format that uses RDFa::Reader/Writer)
* Added :svg format, image/svg+xml and .svg as looks for RDFa parser as well.

### 0.3.1
* Bug fix relating to datatypes in literals being ignored.
* Bug fix parsing non-RDFa profiles to ensure they don't cause processing to terminate (or recurse).

### 0.3.0
* RDF.rb 0.3.0 compatibility updates
  * Remove literal_normalization and qname_hacks, add back uri_hacks (until 0.3.0)
  * URI canonicalization and validation.
  * Added :canonicalize, and :intern options.
  * Change :strict option to :validate.
  * Add check to ensure that predicates are not literals, it's not legal in any RDF variant.
  * Collect prefixes when extracting mappings.
* Added :profile_repository option to RDF::RDFa::Reader.initialize. This MUST be an RDF::Repository and will be used to save profiles that are encountered.
  * Fixme, for now, retrieval should include HTTP headers and perform appropriate HTTP cache control and check for potential updates.
* Update to 2010-10-26 LC version of RDFa Core 1.1
  * Deep processing of XMLLiterals
  * Case sensitive Terms
  * Updated processor graph vocabulary
  * Upgrade for changes to RDFa 1.1 test suite
  * Allow use of xml:base for non-HTML languages
  * XHTML has no default vocabulary.
  * No longer pass vocabularies, prefixes or terms when creating XMLLiterals. Only namespaces derived via xmlns are passed to Literal#typed.
* Literal::XML
  * Add all in-scope namespaces, not just those that seem to be used.
* RSpec 2 compatibility.

### 0.2.2
* Ruby 1.9.2 compatibility
* Added script/parse as command-line option for parsing files.
* Add back support for RDFa 1.0 as well as RDFa 1.1. Parser checks @version to determine which
* Update RDFa processing to WD-rdfa-core-20100803 semantics
  * Added Processor Graph and required output
  * Reverse order of processing profiles
  * Don't process element if any profile fails
  * XMLLiterals must be explicitly specified as @datatype
  * TERMorCURIEorAbsURI requires an absolute URI, not document relative
  * Extract a new default vocabulary from @profile.

### 0.2.1
* Update for RDF 0.2.1

### 0.2.0
* Updates for RDF 0.2.0
  * Use URI#intern instead of URI#new
  * Change use of Graph#predicates and Graph#objects to use as enumerables

### 0.0.3
* Removed internal graph in Reader and implement each_triple & each_statement to perform parsing

### 0.0.2
* Remove dependency on Namespace
* Changed to RDF::RDFa, and moved files accordingly.
* Added vocab definitions for RDA, XHV, XML, XSI and OWL

### 0.0.1
* First port from RdfContext version 0.5.4
