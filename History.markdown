### 0.3.15
* Add support for `@role` attribute.
* Processing defaults to HTML, rather than XML, unless XML is explicitly detected.
* Process embedded RDF:XML, if RDF::RDFXML is loaded, and a RDF/XML is detected.
* Process alternate readers where content is contained within a &lt;script&gt; tag, based on the @type attribute. This is commonly used for N-Triples and Turtle embedded in HTML.
* If @itemscope detected, and RDF::Microdata is loaded, process embedded microdata.

### 0.3.14
* Support for rdf:HTML literal.

### 0.3.13
* Parse any include RDF/XML if RDF::RDFXML is available.
* Add support for extracting RDF from &lt;script&gt; elements.
* Places triples in a named graph if the script has an @id attribute.

### 0.3.11
* Up to date with RDFa Proposed Recomendation versions of specs.
* Fix problems with @resource=\[\] or @about=\[\], which should be ignored and use the next most appropriate attribute.
* Remove support for @data, which was previously a synonym for @src in HTML5.
* More robust detection of XHTML1 if version is rdfa1.0
* Support change to remove @rel/@rev elements that aren't CURIES or IRIs when in the presense of @property

### 0.3.10.1
* Fix case where @datatype and @property are present, but @datatype is empty. (TC 290)

### 0.3.10
* Updated to Candidate Recommendation of drafts:
  * [RDFa 1.1 Core](http://www.w3.org/TR/2012/CR-rdfa-core-20120313/)
  * [RDFa Lite 1.1](http://www.w3.org/TR/2012/CR-rdfa-lite-20120313/)
  * [XHTML+RDFa 1.1](http://www.w3.org/TR/2012/CR-xhtml-rdfa-20120313/)
  * [HTML+RDFa 1.1](http://dev.w3.org/html5/rdfa/)
* change profile to context to conform with change in use in RDFa 1.1.
* Change `:expand\_reader` option to `:vocab\_expansion`, to conform with RDFa Core 1.1 definition.
* Changed `:processor\_graph` to `:processor\_callback` and added `:rdfagraph` option, taking either or both of `:output` and `:processor`.
* Better error recovery is there is no document root.
* Updates to CURIE definition, Term resolution (use @vocab first), and Error/Warning generation in the processor graph.
* `rdfa:usesVocabulary` changed to `rdfa:hasVocabulary`.
* Tolerate errors in vocabulary download when missing.
* Change `SafeCURIEorCURIEorIRI` to not include term.
* Remove `TERMorCURIEorAbsIRIprop`, as it doesn't seem necessary.

### 0.3.9
* Updated to latest working drafts:
  * [RDFa 1.1 Core](http://www.w3.org/TR/2011/WD-rdfa-core-20110331/)
  * [RDFa Lite 1.1](http://www.w3.org/2010/02/rdfa/drafts/2011/ED-rdfa-lite-20111030/)
  * [XHTML+RDFa 1.1](http://www.w3.org/TR/2011/WD-xhtml-rdfa-20110331/)
  * [HTML+RDFa 1.1](http://www.w3.org/TR/2011/WD-rdfa-in-html-20110525/)
* In reader:
  * Don't default xhtml1 and rdfa1.1 in parser; depend on host_detect.
  * Use separate context documents for XML, XHTML and HTML.
  * Remove Facet gem, which was causing problems with Active Record.
  * Added full support for HTML5 &lt;time&gt; element.
  * Added support for HTML5 &lt;data&gt; element with @value attribute to create a plain literal with possible language.
  * Change vocabulary expansion rules to use OWL 2 RL entailment.
  * Terms can now include a '/', to allow for use with @vocab where the class/property is a relative IRI.
* In writer:
  * Don't serialize using XHTML initial context, as it is not used universally.
  * Simplify Haml templates using latest RDFa attribute semantics

### 0.3.8
* Remove hard dependency on Nokogiri. Use it if it is available, otherwise fallback to REXML.
  * JRuby uses REXML due to some implementation issues with the pure-java implementation of Nokogiri.
* Support for RDF Lite 1.1
* Add support for @property doing object references if used with @href/@src/@resource (but no @rel)
* Add support for @property chaining if used with @typeof.
* Change @typeof behavior to add type to object, not subject, unless used with @about.

### 0.3.7
* RDF.rb 0.3.4 compatibility.
* Changed @member to @inlist.
* Added format detection.
* Serialize lists.
* Change @src to be like @resource for RDFa 1.1 (still like @about for RDFa 1.0).
* Fix writer template issues with muti-valued properties

### 0.3.6
* Sync with changes to RDFa 1.1 spec:
  * Deprecate explicit use of @profile
  * Add rdfa:hasVocabulary when encountering @vocab
  * Implemented Reader#expand to perform vocabulary expansion using RDFS rules 5, 7, 9 and 11.
  * Support for RDF collections (rdf:List) using @member attribute.
  * Implemented :expand option to reader, which allows normal use of reader interface without requiring the use of the #expand method.
  * Add caches for popular vocabularies to speed load time.
  * Add :vocabulary_profile as Reader option to allow for use of persistent vocabulary caches.
  * Performance improvements by evaluating debug statements in block only when debug enabled.
  
### 0.3.5
* Updates to writer necessary for structure-data.org linter.
  * Support for type-specific templates and types matching a regular expression.
  * Allow #find-template to be overridden in subclasses.
* In reader
  * Fix initialization bugs when passed an Nokogiri::XML::Document or Nokogiri::HTML::Document.
  * Fixed bug where @typeof was ignored in the root element.

### 0.3.4.2
* Fix Writer output for multi-valued properties when there is no :property\_values Haml template.
* Simplify templates by using pre-rendered CURIEs.

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
