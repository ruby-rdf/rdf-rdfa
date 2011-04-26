# RDF::RDFa reader/writer

[RDFa][RDFa 1.1 Core] parser for RDF.rb.

## DESCRIPTION
RDF::RDFa is an RDFa reader and writer for Ruby using the [RDF.rb][RDF.rb] library suite.

## FEATURES
RDF::RDFa parses [RDFa][RDFa 1.1 Core] into statements or triples.

* Fully compliant RDFa 1.1 parser.
* Template-based Writer to generate XHTML+RDFa.
  * Writer uses user-replacable [Haml][Haml]-based templates to generate RDFa.
* Uses Nokogiri for parsing HTML/SVG
* [RDFa tests][RDFa-test-suite] use SPARQL for most tests due to Rasqal limitations. Other tests compare directly against N-triples.

Install with 'gem install rdf-rdfa'

## Usage

### Reading RDF data in the RDFa format

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

Note that prefixes may be chained between Reader and Writer, so that the Writer will
use the same prefix definitions found during parsing:

    prefixes = {}
    graph = RDF::Graph.load("etc/foaf.html", :prefixes => prefixes)
    puts graph.dump(:rdfa, :prefixes => prefixes)
    
### Template-based Writer
The RDFa writer uses [Haml][Haml] templates for code generation. This allows fully customizable
RDFa output in a variety of host languages. The [default template]({RDF::RDFa::Writer::DEFAULT_HAML})
generates human readable HTML5 output. A [minimal template]({RDF::RDFa::Writer::MIN_HAML})
generates HTML, which is not intended for human consumption.

To specify an alternative Haml template, consider the following:

    require 'rdf/rdfa'
    
    RDF::RDFa::Writer.buffer(:haml => RDF::RDFa::Writer::MIN_HAML) << graph

The template hash defines four Haml templates:

*   _doc_: Document Template, takes an ordered list of _subject_s and yields each one to be rendered.
    Described further in {RDF::RDFa::Writer#render_document}.

        !!! XML
        !!! 5
        %html{:xmlns => "http://www.w3.org/1999/xhtml", :lang => lang, :profile => profile, :prefix => prefix}
          - if base || title
            %head
              - if base
                %base{:href => base}
              - if title
                %title= title
          %body
            - subjects.each do |subject|
              != yield(subject)

    This template takes locals _lang_, _profile_, _prefix_, _base_, _title_ in addition to _subjects_
    to create output similar to the following:
      
        <!DOCTYPE html>
        <html prefix='xhv: http://www.w3.org/1999/xhtml/vocab#' xmlns='http://www.w3.org/1999/xhtml'>
          <head>
            <base href="http://example/">
            <title>Document Title</title>
          </head>
          <body>
            ...
          </body>
        </html>
      
    Options passed to the Writer are used to supply _lang_, _profile_ and _base_ locals.
    _prefix_ is generated based upon prefixes found from default or supplied profiles, as well
    as those provided by a previous Reader. _title_ is taken from the first top-level subject
    having an appropriate title property (as defined by the _heading_predicates_ option).

*   _subject_: Subject Template, take a _subject_ and an order list of _predicate_s and yields
    each _predicate_ to be rendered. Described further in {RDF::RDFa::Writer#render_subject}.
    
        - if element == :li
          %li{:about => get_curie(subject), :typeof => typeof}
            - if typeof
              %span.type!= typeof
            - predicates.each do |predicate|
              != yield(predicate)
        - elsif rel && typeof
          %div{:rel => get_curie(rel)}
            %div{:about => get_curie(subject), :typeof => typeof}
              %span.type!= typeof
              - predicates.each do |predicate|
                != yield(predicate)
        - elsif rel
          %div{:rel => get_curie(rel), :resource => get_curie(subject)}
            - predicates.each do |predicate|
              != yield(predicate)
        - else
          %div{:about => get_curie(subject), :typeof => typeof}
            - if typeof
              %span.type!= typeof
            - predicates.each do |predicate|
              != yield(predicate)
    
    The template takes locals _rel_ and _typeof_ in addition to _predicates_ and _subject_ to
    create output similar to the following:
    
        <div about="http://example/">
          ...
        </div>

    Note that if _typeof_ is defined, in this template, it will generate a textual description.
    
*   _property\_value_: Property Value Template, used for predicates having a single value; takes
    a _predicate_, and a single-valued Array of _objects_. Described further in {RDF::RDFa::Writer#render\_property}.
    
        - object = objects.first
        - if heading_predicates.include?(predicate) && object.literal?
          %h1{:property => get_curie(predicate), :content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object)}&= get_value(object)
        - else
          %div.property
            %span.label
              = get_predicate_name(predicate)
            - if res = yield(object)
              != res
            - elsif object.node?
              %span{:resource => get_curie(object), :rel => get_curie(predicate)}= get_curie(object)
            - elsif object.uri?
              %a{:href => object.to_s, :rel => get_curie(predicate)}= object.to_s
            - elsif object.datatype == RDF.XMLLiteral
              %span{:property => get_curie(predicate), :lang => get_lang(object), :datatype => get_dt_curie(object)}<!= get_value(object)
            - else
              %span{:property => get_curie(predicate), :content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object)}&= get_value(object)
   
    In addition to _predicate_ and _objects_, the template takes locals _property_ and/or _rel_, which are
    copies of _predicate_ and indicate use in the @property or @rel attributes. Either or both may be
    specified, as the conditions dictate.

    Also, if the predicate is identified as a _heading predicate_ (via _:heading\_predicates_ option),
    it will generate a heading element, and may use the value as the document title.

    Each _object_ is yielded to the calling block, and the result is rendered, unless nil.
    Otherwise, rendering depends on the type of _object_. This is useful for recursive document
    descriptions.

    Creates output similar to the following:
    
        <div class='property'>
          <span class='label'>
            xhv:alternate
          </span>
          <a href='http://rdfa.info/feed/' rel='xhv:alternate'>http://rdfa.info/feed/</a>
        </div>
    
    Note the use of methods defined in {RDF::RDFa::Writer} useful in rendering the output.
    
*   _property\_values_: Similar to _property\_value_, but for predicates having more than one value.
    Locals are identical to _property\_values_, but _objects_ is expected to have more than one value.
    
        %div.property
          %span.label
            = get_predicate_name(predicate)
          %ul{:rel => (get_curie(rel) if rel), :property => (get_curie(property) if property)}
            - objects.each do |object|
              - if res = yield(object)
                != res
              - elsif object.node?
                %li{:resource => get_curie(object)}= get_curie(object)
              - elsif object.uri?
                %li
                  %a{:href => object.to_s}= object.to_s
              - elsif object.datatype == RDF.XMLLiteral
                %li{:lang => get_lang(object), :datatype => get_curie(object.datatype)}<!= get_value(object)
              - else
                %li{:content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object)}&= get_value(object)
  
    In this case, and unordered list is used for output. Creates output similar to the following:
    
        <div class='property'>
          <span class='label'>
            xhv:bookmark
          </span>
          <ul rel='xhv:bookmark'>
            <li>
              <a href='http://rdfa.info/2009/12/12/oreilly-catalog-uses-rdfa/'>
                http://rdfa.info/2009/12/12/oreilly-catalog-uses-rdfa/
              </a>
            </li>
              <a href='http://rdfa.info/2010/05/31/new-rdfa-checker/'>
                http://rdfa.info/2010/05/31/new-rdfa-checker/
              </a>
            </li>
          </ul>
        </div>

## Dependencies
* [RDF.rb](http://rubygems.org/gems/rdf) (>= 0.3.1)
* [Nokogiri](http://rubygems.org/gems/nokogiri) (>= 1.3.3)
* [Haml](https://rubygems.org/gems/haml) (>= 3.0.0)

## Documentation
Full documentation available on [RubyForge](http://rdf.rubyforge.org/rdfa)

### Principle Classes
* {RDF::RDFa::Format}
  * {RDF::RDFa::HTML}
    Asserts :html format, text/html mime-type and .html file extension.
  * {RDF::RDFa::XHTML}
    Asserts :html format, application/xhtml+xml mime-type and .xhtml file extension.
  * {RDF::RDFa::SVG}
    Asserts :svg format, image/svg+xml mime-type and .svg file extension.
* {RDF::RDFa::Reader}
* {RDF::RDFa::Profile}
* {RDF::RDFa::Writer}

### Additional vocabularies
* {RDF::PTR}
* {RDF::RDFA}
* {RDF::XHV}
* {RDF::XML}
* {RDF::XSI}

## TODO
* Add support for LibXML and REXML bindings, and use the best available
* Consider a SAX-based parser for improved performance

## Resources
* [RDF.rb][RDF.rb]
* [Distiller](http://distiller.kellogg-assoc)
* [Documentation](http://rdf.rubyforge.org/rdfa)
* [History](file:file.History.html)
* [RDFa 1.1 Core][RDFa 1.1 Core]
* [XHTML+RDFa 1.1][XHTML+RDFa 1.1]
* [RDFa-test-suite](http://rdfa.digitalbazaar.com/test-suite/              "RDFa test suite")

## Author
* [Gregg Kellogg](http://github.com/gkellogg) - <http://kellogg-assoc.com/>

## Contributors
* [Nicholas Humfrey](http://github.com/njh)

## Contributing

* Do your best to adhere to the existing coding conventions and idioms.
* Don't use hard tabs, and don't leave trailing whitespace on any line.
* Do document every method you add using [YARD][] annotations. Read the
  [tutorial][YARD-GS] or just look at the existing code for examples.
* Don't touch the `.gemspec`, `VERSION` or `AUTHORS` files. If you need to
  change them, do so on your private branch only.
* Do feel free to add yourself to the `CREDITS` file and the corresponding
  list in the the `README`. Alphabetical order applies.
* Do note that in order for us to merge any non-trivial changes (as a rule
  of thumb, additions larger than about 15 lines of code), we need an
  explicit [public domain dedication][PDD] on record from you.

## License

This is free and unencumbered public domain software. For more information,
see <http://unlicense.org/> or the accompanying {file:UNLICENSE} file.

## FEEDBACK

* gregg@kellogg-assoc.com
* <http://rubygems.org/rdf-rdfa>
* <http://github.com/gkellogg/rdf-rdfa>
* <http://lists.w3.org/Archives/Public/public-rdf-ruby/>

[RDF.rb]:           http://rdf.rubyforge.org/
[YARD]:             http://yardoc.org/
[YARD-GS]:          http://rubydoc.info/docs/yard/file/docs/GettingStarted.md
[PDD]:              http://lists.w3.org/Archives/Public/public-rdf-ruby/2010May/0013.html
[RDFa 1.1 Core]:    http://www.w3.org/TR/2010/WD-rdfa-core-20100422/     "RDFa 1.1 Core"
[XHTML+RDFa 1.1]:   http://www.w3.org/TR/2010/WD-xhtml-rdfa-20100422/   "XHTML+RDFa 1.1"
[RDFa-test-suite]:  http://rdfa.digitalbazaar.com/test-suite/           "RDFa test suite"
[Haml]:             http://haml-lang.com/
