# RDF::RDFa reader/writer

[RDFa][RDFa 1.1 Core] parser for RDF.rb.

## DESCRIPTION
RDF::RDFa is an RDFa reader and writer for Ruby using the [RDF.rb][RDF.rb] library suite.

## FEATURES
RDF::RDFa parses [RDFa][RDFa 1.1 Core] into statements or triples.

* Fully compliant RDFa 1.1 parser.
* Template-based Writer to generate XHTML+RDFa.
  * Writer uses user-replacable [Haml][Haml]-based templates to generate RDFa.
* If available, Uses Nokogiri for parsing HTML/SVG, falls back to REXML otherwise (and for JRuby)
* [RDFa tests][RDFa-test-suite] use SPARQL for most tests due to Rasqal limitations. Other tests compare directly against N-triples.

Install with 'gem install rdf-rdfa'

### Important changes from previous versions
RDFa is an evolving standard, undergoing some substantial recent changes partly due to perceived competition
with Microdata. As a result, the RDF Webapps working group is currently looking at changes in the processing model for RDFa. These changes are now being tracked in {RDF::RDFa::Reader}:

#### Remove RDFa Profiles
RDFa Profiles were a mechanism added to allow groups of terms and prefixes to be defined in an external resource and loaded to affect the processing of an RDFa document. This introduced a problem for some implementations needing to perform a cross-origin GET in order to retrieve the profiles. The working group elected to drop support for user-defined RDFa Profiles (the default profiles defined by RDFa Core and host languages still apply) and replace it with an inference regime using vocabularies. Parsing of @profile has been removed from this version.

#### Vocabulary Expansion
One of the issues with vocabularies was that they discourage re-use of existing vocabularies when terms from several vocabularies are used at the same time. As it is common (encouraged) for RDF vocabularies to form sub-class and/or sub-property relationships with well defined vocabularies, the RDFa vocabulary expansion mechanism takes advantage of this.

As an optional part of RDFa processing, an RDFa processor will perform limited [RDFS entailment](http://www.w3.org/TR/rdf-mt/#rules), specifically rules rdfs5, 7, 9 and 11. This causes sub-classes and sub-properties of type and property IRIs to be added to the output graph.

{RDF::RDFa::Reader} implements this using the `#expand` method, which looks for `rdfa:hasVocabulary` properties within the output graph and performs such expansion. See an example in the usage section.

#### RDF Collections (lists)
One significant RDF feature missing from RDFa was support for ordered collections, or lists. RDF supports this with special properties `rdf:first`, `rdf:rest`, and `rdf:nil`, but other RDF languages have first-class support for this concept. For example, in [Turtle][Turtle], a list can be defined as follows:

    [ a schema:MusicPlayList;
      schema:name "Classic Rock Playlist";
      schema:numTracks 5;
      schema:tracks (
        [ a schema:MusicRecording; schema:name "Sweet Home Alabama";       schema:byArtist "Lynard Skynard"]
        [ a schema:MusicRecording; schema:name "Shook you all Night Long"; schema:byArtist "AC/DC"]
        [ a schema:MusicRecording; schema:name "Sharp Dressed Man";        schema:byArtist "ZZ Top"]
        [ a schema:MusicRecording; schema:name "Old Time Rock and Roll";   schema:byArtist "Bob Seger"]
        [ a schema:MusicRecording; schema:name "Hurt So Good";             schema:byArtist "John Cougar"]
      )
    ]

defines a playlist with an ordered set of tracks. RDFa adds the @inlist attribute, which is used to identify values (object or literal) that are to be placed in a list. The same playlist might be defined in RDFa as follows:

    <div vocab="http://schema.org/" typeof="MusicPlaylist">
      <span property="name">Classic Rock Playlist</span>
      <meta property="numTracks" content="5"/>

      <div rel="tracks" inlist="">
        <div typeof="MusicRecording">
          1.<span property="name">Sweet Home Alabama</span> -
          <span property="byArtist">Lynard Skynard</span>
         </div>

        <div typeof="MusicRecording">
          2.<span property="name">Shook you all Night Long</span> -
          <span property="byArtist">AC/DC</span>
        </div>

        <div typeof="MusicRecording">
          3.<span property="name">Sharp Dressed Man</span> -
          <span property="byArtist">ZZ Top</span>
        </div>

        <div typeof="MusicRecording">
          4.<span property="name">Old Time Rock and Roll</span>
          <span property="byArtist">Bob Seger</span>
        </div>

        <div typeof="MusicRecording">
          5.<span property="name">Hurt So Good</span>
          <span property="byArtist">John Cougar</span>
        </div>
      </div>
    </div>

This basically does the same thing, but places each track in an rdf:List in the defined order.

## Usage

### Reading RDF data in the RDFa format

    graph = RDF::Graph.load("etc/doap.html", :format => :rdfa)

### Reading RDF data with vocabulary expansion

    graph = RDF::Graph.load("etc/doap.html", :format => :rdfa, :expand => true)

or

    graph = RDF::RDFa::Reader.open("etc/doap.html").expand

### Writing RDF data using the XHTML+RDFa format

    require 'rdf/rdfa'
    
    RDF::RDFa::Writer.open("etc/doap.html") do |writer|
      writer << graph
    end

Note that prefixes may be chained between Reader and Writer, so that the Writer will
use the same prefix definitions found during parsing:

    prefixes = {}
    graph = RDF::Graph.load("etc/foaf.html", :prefixes => prefixes)
    puts graph.dump(:rdfa, :prefixes => prefixes)

### Template-based Writer
The RDFa writer uses [Haml][Haml] templates for code generation. This allows fully
customizable RDFa output in a variety of host languages.
The [default template]({RDF::RDFa::Writer::DEFAULT_HAML}) generates human readable HTML5
output. A [minimal template]({RDF::RDFa::Writer::MIN_HAML}) generates HTML, which is not
intended for human consumption.

To specify an alternative Haml template, consider the following:

    require 'rdf/rdfa'
    
    RDF::RDFa::Writer.buffer(:haml => RDF::RDFa::Writer::MIN_HAML) << graph

The template hash defines four Haml templates:

*   _doc_: Document Template, takes an ordered list of _subject_s and yields each one to be rendered.
    Described further in {RDF::RDFa::Writer#render_document}.

        !!! XML
        !!! 5
        %html{:xmlns => "http://www.w3.org/1999/xhtml", :lang => lang, :prefix => prefix}
          - if base || title
            %head
              - if base
                %base{:href => base}
              - if title
                %title= title
          %body
            - subjects.each do |subject|
              != yield(subject)

    This template takes locals _lang_, _prefix_, _base_, _title_ in addition to _subjects_
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
      
    Options passed to the Writer are used to supply _lang_ and _base_ locals.
    _prefix_ is generated based upon prefixes found from the default profiles, as well
    as those provided by a previous Reader. _title_ is taken from the first top-level subject
    having an appropriate title property (as defined by the _heading_predicates_ option).

*   _subject_: Subject Template, take a _subject_ and an ordered list of _predicate_s and yields
    each _predicate_ to be rendered. Described further in {RDF::RDFa::Writer#render_subject}.
    
        - if element == :li
          %li{:rel => rel, :resource => resource, :inlist => inlist}
            - if typeof
              %span{:rel => 'rdf:type', :resource => typeof}.type!= typeof
            - predicates.each do |predicate|
              != yield(predicate)
        - elsif rel && typeof
          %div{:rel => rel}
            %div{:about => resource, :typeof => typeof}
              %span.type!= typeof
              - predicates.each do |predicate|
                != yield(predicate)
        - elsif rel
          %div{:rel => rel, :resource => resource}
            - predicates.each do |predicate|
              != yield(predicate)
        - else
          %div{:about => about, :typeof => typeof}
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
    
        - if heading_predicates.include?(predicate) && object.literal?
          %h1{:property => get_curie(predicate), :content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object), :inlist => inlist}= escape_entities(get_value(object))
        - else
          %div.property
            %span.label
              = get_predicate_name(predicate)
            - if res = yield(object)
              != res
            - elsif get_curie(object) == 'rdf:nil'
              %span{:rel => get_curie(predicate), :inlist => ''}
            - elsif object.node?
              %span{:resource => get_curie(object), :rel => get_curie(predicate), :inlist => inlist}= get_curie(object)
            - elsif object.uri?
              %a{:href => object.to_s, :rel => get_curie(predicate), :inlist => inlist}= object.to_s
            - elsif object.datatype == RDF.XMLLiteral
              %span{:property => get_curie(predicate), :lang => get_lang(object), :datatype => get_dt_curie(object), :inlist => inlist}<!= get_value(object)
            - else
              %span{:property => get_curie(predicate), :content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object), :inlist => inlist}= escape_entities(get_value(object))
   
    In addition to _predicate_ and _objects_, the template takes _inlist_ to indicate that the
    property is part of an rdf:List.

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
          %ul
            - objects.each do |object|
              - if res = yield(object)
                != res
              - elsif object.node?
                %li{:rel => get_curie(predicate), :resource => get_curie(object), :inlist => inlist}= get_curie(object)
              - elsif object.uri?
                %li
                  %a{:rel => get_curie(predicate), :href => object.to_s, :inlist => inlist}= object.to_s
              - elsif object.datatype == RDF.XMLLiteral
                %li{:property => get_curie(predicate), :lang => get_lang(object), :datatype => get_curie(object.datatype), :inlist => inlist}<!= get_value(object)
              - else
                %li{:property => get_curie(predicate), :content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object), :inlist => inlist}= escape_entities(get_value(object))
  
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
    If _property\_values_ does not exist, repeated values will be replecated
    using _property\_value_.
* Type-specific templates.
  To simplify generation of different output types, the
  template may contain a elements indexed by a URI. When a subject with an rdf:type
  matching that URI is found, subsequent Haml definitions will be taken from
  the associated Hash. For example:
  
    {
      :document => "...",
      :subject => "...",
      :property\_value => "...",
      :property\_values => "...",
      RDF::URI("http://schema.org/Person") => {
        :subject => "...",
        :property\_value => "...",
        :property\_values => "...",
      }
    }

## Dependencies
* [RDF.rb](http://rubygems.org/gems/rdf) (>= 0.3.1)
* [Haml](https://rubygems.org/gems/haml) (>= 3.0.0)
* [HTMLEntities](https://rubygems.org/gems/htmlentities) ('>= 4.3.0')
* Soft dependency on [Nokogiri](http://rubygems.org/gems/nokogiri) (>= 1.3.3)

## Documentation
Full documentation available on [Rubydoc.info][RDFa doc]

### Principle Classes
* {RDF::RDFa::Format}
  * {RDF::RDFa::HTML}
    Asserts :html format, text/html mime-type and .html file extension.
  * {RDF::RDFa::XHTML}
    Asserts :html format, application/xhtml+xml mime-type and .xhtml file extension.
  * {RDF::RDFa::SVG}
    Asserts :svg format, image/svg+xml mime-type and .svg file extension.
* {RDF::RDFa::Reader}
  * {RDF::RDFa::Reader::Nokogiri}
  * {RDF::RDFa::Reader::REXML}
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
* [Distiller](http://rdf.greggkellogg.net/distiller)
* [Documentation][RDFa doc]
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
[RDFa 1.1 Core]:    http://www.w3.org/TR/2011/WD-rdfa-core-20110331/     "RDFa 1.1 Core"
[XHTML+RDFa 1.1]:   http://www.w3.org/TR/2011/WD-xhtml-rdfa-20110331/   "XHTML+RDFa 1.1"
[RDFa-test-suite]:  http://rdfa.digitalbazaar.com/test-suite/           "RDFa test suite"
[RDFa doc]:         http://rubydoc.info/github/gkellogg/rdf-rdfa/frames
[Haml]:             http://haml-lang.com/
[Turtle]:           http://www.w3.org/TR/2011/WD-turtle-20110809/
