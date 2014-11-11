# -*- encoding: utf-8 -*-
# This file generated automatically using vocab-fetch from http://rdfa.info/vocabs/rdfa-test#
require 'rdf'
module RDF
  class RDFATest < RDF::StrictVocabulary("http://rdfa.info/vocabs/rdfa-test#")

    # Class definitions
    term :BaseClass,
      label: "BaseClass".freeze,
      type: "rdfs:Class".freeze
    term :EqClass,
      label: "EqClass".freeze,
      "owl:equivalentClass" => %(http://rdfa.info/vocabs/rdfa-test#BaseClass).freeze,
      type: "rdfs:Class".freeze
    term :SubClass,
      label: "SubClass".freeze,
      subClassOf: "http://rdfa.info/vocabs/rdfa-test#BaseClass".freeze,
      type: "rdfs:Class".freeze
    term :Version,
      comment: %(
            Version
            defines the Container Class for Version containing a list of
            rdfatest:hostLanguageReport properties.
          ).freeze,
      label: "Version".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      type: "owl:Class".freeze

    # Property definitions
    property :baseProp,
      label: "baseProp".freeze,
      type: "rdf:Property".freeze
    property :eqProp,
      label: "eqProp".freeze,
      "owl:equivalentProperty" => %(http://rdfa.info/vocabs/rdfa-test#baseProp).freeze,
      type: "rdf:Property".freeze
    property :hostLanguage,
      comment: %(
            Host Language
            defines the
            Host Languages
            for which this test is defined. Appropriate values include
            html4,
            html5,
            svg,
            xhtml1,
            xhtml5, and
            xml.
          ).freeze,
      domain: "http://rdfa.info/vocabs/rdfa-test#TestCase".freeze,
      label: "Host Language".freeze,
      range: "xsd:string".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      type: "owl:DatatypeProperty".freeze
    property :"hostLanguage/html4",
      "dc:description" => %(
            The HTML4 [[HTML40]] RDFa Host Language is defined in [[HTML-RDFA]]. HTML+RDFa extends
            RDFa Core 1.1 [[RDFA-CORE]] with host-language specific processing rules.
          ).freeze,
      label: "HTML4".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      subClassOf: "http://rdfa.info/vocabs/rdfa-test#hostLanguageReport".freeze,
      type: "owl:DatatypeProperty".freeze
    property :"hostLanguage/html5",
      "dc:description" => %(
            The HTML5 [[HTML5]] RDFa Host Language is defined in [[HTML-RDFA]]. HTML+RDFa extends
            RDFa Core 1.1 [[RDFA-CORE]] with host-language specific processing rules.
          ).freeze,
      label: "HTML5".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      subClassOf: "http://rdfa.info/vocabs/rdfa-test#hostLanguageReport".freeze,
      type: "owl:DatatypeProperty".freeze
    property :"hostLanguage/svg",
      "dc:description" => %(
            SVG [[SVG12]] supports RDFa by virtue of being an XML-based language, so the XML+RDFa
            rules defined in RDFa Core 1.1 [[RDFA-CORE]] apply to processing RDFa in SVG.
          ).freeze,
      label: "SVG".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      subClassOf: "http://rdfa.info/vocabs/rdfa-test#hostLanguageReport".freeze,
      type: "owl:DatatypeProperty".freeze
    property :"hostLanguage/xhtml1",
      "dc:description" => %(
            XHTML+RDFa 1.1 [[XHTML-RDFA]] extends
            RDFa Core 1.1 [[RDFA-CORE]] with host-language specific processing rules.
          ).freeze,
      label: "XHTML1".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      subClassOf: "http://rdfa.info/vocabs/rdfa-test#hostLanguageReport".freeze,
      type: "owl:DatatypeProperty".freeze
    property :"hostLanguage/xhtml5",
      "dc:description" => %(
            The HTML5 [[HTML5]] RDFa Host Language is defined in [[HTML-RDFA]]. HTML+RDFa extends
            RDFa Core 1.1 [[RDFA-CORE]] with host-language specific processing rules.
          ).freeze,
      label: "XHTML5".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      subClassOf: "http://rdfa.info/vocabs/rdfa-test#hostLanguageReport".freeze,
      type: "owl:DatatypeProperty".freeze
    property :"hostLanguage/xml",
      "dc:description" => %(
            The XML [[XML11]] RDFa Host Language uses the generic [[RDFA-CORE]] processing rules.
          ).freeze,
      label: "XML".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      subClassOf: "http://rdfa.info/vocabs/rdfa-test#hostLanguageReport".freeze,
      type: "owl:DatatypeProperty".freeze
    property :hostLanguageReport,
      domain: "http://rdfa.info/vocabs/rdfa-test#Version".freeze,
      label: ["Host Language Report".freeze, "host language report".freeze],
      range: "rdf:List".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      type: "owl:DatatypeProperty".freeze
    property :num,
      comment: %(
            Number
            defines the
            Test Number
            of this test.
          ).freeze,
      domain: "http://www.w3.org/ns/earl#TestCase".freeze,
      label: ["Num".freeze, "Test Number".freeze],
      range: "xsd:string".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      type: "owl:DatatypeProperty".freeze
    property :queryParam,
      comment: %(
            Query Param
            defines query parameters to add to the
            processor URL
            when running this test.
          ).freeze,
      domain: "http://rdfa.info/vocabs/rdfa-test#TestCase".freeze,
      label: ["Query Param".freeze, "query parameters".freeze],
      range: "xsd:string".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      type: "owl:DatatypeProperty".freeze
    property :rdfaVersion,
      comment: %(
            RDFa Version
            defines the
            RDFa version numbers
            for which this test is defined. Appropriate values include
            rdfa1.0,
            rdfa1.1,
            rdfa1.1-proc,
            rdfa1.1-role and
            rdfa1.1-vocab.
          ).freeze,
      domain: "http://rdfa.info/vocabs/rdfa-test#TestCase".freeze,
      label: ["RDFa Version".freeze, "RDFa version numbers".freeze],
      range: "xsd:string".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      type: "owl:DatatypeProperty".freeze
    property :subProp,
      label: "subProp".freeze,
      subPropertyOf: "http://rdfa.info/vocabs/rdfa-test#baseProp".freeze,
      type: "rdf:Property".freeze
    property :"version/rdfa1.0",
      "dc:description" => %(
            RDFa 1.0 [[RDFA-SYNTAX]] defines core processing rules for RDFa in XHTML [[XHTML11]].
          ).freeze,
      label: "RDFa 1.0".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      subClassOf: "http://rdfa.info/vocabs/rdfa-test#versionReport".freeze,
      type: "owl:DatatypeProperty".freeze
    property :"version/rdfa1.1",
      "dc:description" => %(
            RDFa Core 1.1 [[RDFA-CORE]] defines core processing rules for independent of host
            language, and provides default processing rules for XML-based host languages.
          ).freeze,
      label: "RDFa 1.1".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      subClassOf: "http://rdfa.info/vocabs/rdfa-test#versionReport".freeze,
      type: "owl:DatatypeProperty".freeze
    property :"version/rdfa1.1-proc",
      "dc:description" => %(
            RDFa Core 1.1 [[RDFA-CORE]]
            <cite><a href="http://www.w3.org/TR/rdfa-core/#processor-status">Processor Status</a></cite>
            is an optional RDFa feature used to add triples for reporting
            on errors, warnings and other information. The processor adds a
            <code>@rdfagraph</code> attribute to indicate if the processor
            should return the <em>output graph</em>, <em>processor graph</em>,
            or both.
          ).freeze,
      label: "RDFa 1.1 Processor Graph".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      subClassOf: "http://rdfa.info/vocabs/rdfa-test#versionReport".freeze,
      type: "owl:DatatypeProperty".freeze
    property :"version/rdfa1.1-role",
      "dc:description" => %(
            XHTML Role Attribute Module [[XHTML-ROLE]]
            is a specification for generating triples from the HTML
            <code>@role</code> attribute.
          ).freeze,
      label: "Role Attribute".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      subClassOf: "http://rdfa.info/vocabs/rdfa-test#versionReport".freeze,
      type: "owl:DatatypeProperty".freeze
    property :"version/rdfa1.1-vocab",
      "dc:description" => %(
            RDFa Core 1.1 [[RDFA-CORE]]
            <cite><a href="http://www.w3.org/TR/rdfa-core/#s_vocab_expansion">Vocabulary Expansion</a></cite>
            is an optional RDFa extension used to perform
            limited OWL and RDFS expansion of terms associated with a Vocabulary.
          ).freeze,
      label: "RDFa 1.1 Vocabulary".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      subClassOf: "http://rdfa.info/vocabs/rdfa-test#versionReport".freeze,
      type: "owl:DatatypeProperty".freeze
    property :versionReport,
      domain: "earl:Software".freeze,
      label: "version report".freeze,
      range: "http://rdfa.info/vocabs/rdfa-test#Version".freeze,
      "rdfs:isDefinedBy" => %(http://rdfa.info/vocabs/rdfa-test).freeze,
      type: "owl:DatatypeProperty".freeze
  end
end
