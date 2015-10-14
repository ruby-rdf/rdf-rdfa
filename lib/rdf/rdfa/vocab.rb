# -*- encoding: utf-8 -*-
module RDF
  class RDFA < Vocabulary("http://www.w3.org/ns/rdfa#")
    # Class definitions
    __property__ :DocumentError,
      comment: %(error condition; to be used when the document fails to be fully processed as a result of non-conformant host language markup).freeze,
      "dc:description" => %(error condition; to be used when the document fails to be fully processed as a result of non-conformant host language markup).freeze,
      label: "DocumentError".freeze,
      subClassOf: "rdfa:Error".freeze,
      type: "rdfs:Class".freeze
    __property__ :Error,
      comment: %(is the class for all error conditions).freeze,
      "dc:description" => %(is the class for all error conditions).freeze,
      label: "Error".freeze,
      subClassOf: "rdfa:PGClass".freeze.freeze,
      type: "rdfs:Class".freeze
    __property__ :Info,
      comment: %(is the class for all informations).freeze,
      "dc:description" => %(is the class for all informations).freeze,
      label: "Info".freeze,
      subClassOf: "rdfa:PGClass".freeze.freeze,
      type: "rdfs:Class".freeze
    __property__ :PGClass,
      comment: %(is the top level class of the hierarchy).freeze,
      "dc:description" => %(is the top level class of the hierarchy).freeze,
      label: "PGClass".freeze,
      type: ["rdfs:Class".freeze, "owl:Class".freeze]
    __property__ :Pattern,
      comment: %(Class to identify an \(RDF\) resource whose properties are to be copied to another resource).freeze,
      "dc:description" => %(Class to identify an \(RDF\) resource whose properties are to be copied to another resource).freeze,
      label: "Pattern".freeze,
      type: ["rdfs:Class".freeze, "owl:Class".freeze]
    __property__ :PrefixMapping,
      comment: %(is the class for prefix mappings).freeze,
      "dc:description" => %(is the class for prefix mappings).freeze,
      label: "PrefixMapping".freeze,
      subClassOf: "rdfa:PrefixOrTermMapping".freeze.freeze,
      type: "rdfs:Class".freeze
    __property__ :PrefixOrTermMapping,
      comment: %(is the top level class for prefix or term mappings).freeze,
      "dc:description" => %(is the top level class for prefix or term mappings).freeze,
      label: "PrefixOrTermMapping".freeze,
      type: ["rdfs:Class".freeze, "owl:Class".freeze]
    __property__ :PrefixRedefinition,
      comment: %(warning; to be used when a prefix, either from the initial context or inherited from an ancestor node, is redefined in an element).freeze,
      "dc:description" => %(warning; to be used when a prefix, either from the initial context or inherited from an ancestor node, is redefined in an element).freeze,
      label: "PrefixRedefinition".freeze,
      subClassOf: "rdfa:Warning".freeze.freeze,
      type: "rdfs:Class".freeze
    __property__ :TermMapping,
      comment: %(is the class for term mappings).freeze,
      "dc:description" => %(is the class for term mappings).freeze,
      label: "TermMapping".freeze,
      subClassOf: "rdfa:PrefixOrTermMapping".freeze.freeze,
      type: "rdfs:Class".freeze
    __property__ :UnresolvedCURIE,
      comment: %(warning; to be used when a CURIE prefix fails to be resolved).freeze,
      "dc:description" => %(warning; to be used when a CURIE prefix fails to be resolved).freeze,
      label: "UnresolvedCURIE".freeze,
      subClassOf: "rdfa:Warning".freeze.freeze,
      type: "rdfs:Class".freeze
    __property__ :UnresolvedTerm,
      comment: %(warning; to be used when a Term fails to be resolved).freeze,
      "dc:description" => %(warning; to be used when a Term fails to be resolved).freeze,
      label: "UnresolvedTerm".freeze,
      subClassOf: "rdfa:Warning".freeze.freeze,
      type: "rdfs:Class".freeze
    __property__ :VocabReferenceError,
      comment: %(warning; to be used when the value of a @vocab attribute cannot be dereferenced, hence the vocabulary expansion cannot be completed).freeze,
      "dc:description" => %(warning; to be used when the value of a @vocab attribute cannot be dereferenced, hence the vocabulary expansion cannot be completed).freeze,
      label: "VocabReferenceError".freeze,
      subClassOf: "rdfa:Warning".freeze.freeze,
      type: "rdfs:Class".freeze
    __property__ :Warning,
      comment: %(is the class for all warnings).freeze,
      "dc:description" => %(is the class for all warnings).freeze,
      label: "Warning".freeze,
      subClassOf: "rdfa:PGClass".freeze.freeze,
      type: "rdfs:Class".freeze

    # Property definitions
    __property__ :context,
      comment: %(provides extra context for the error, eg, http response, an XPointer/XPath information, or simply the URI that created the error).freeze,
      "dc:description" => %(provides extra context for the error, eg, http response, an XPointer/XPath information, or simply the URI that created the error).freeze,
      domain: "rdfa:PGClass".freeze,
      label: "context".freeze,
      type: ["rdf:Property".freeze, "owl:ObjectProperty".freeze]
    __property__ :copy,
      comment: %(identifies the resource \(i.e., pattern\) whose properties and values should be copied to replace the current triple \(retaining the subject of the triple\).).freeze,
      "dc:description" => %(identifies the resource \(i.e., pattern\) whose properties and values should be copied to replace the current triple \(retaining the subject of the triple\).).freeze,
      label: "copy".freeze,
      type: ["rdf:Property".freeze, "owl:ObjectProperty".freeze]
    __property__ :prefix,
      comment: %(defines a prefix mapping for a URI; the value is supposed to be a NMTOKEN).freeze,
      "dc:description" => %(defines a prefix mapping for a URI; the value is supposed to be a NMTOKEN).freeze,
      domain: "rdfa:PrefixMapping".freeze,
      label: "prefix".freeze,
      type: ["rdf:Property".freeze, "owl:DatatypeProperty".freeze]
    __property__ :term,
      comment: %(defines a term mapping for a URI; the value is supposed to be a NMTOKEN).freeze,
      "dc:description" => %(defines a term mapping for a URI; the value is supposed to be a NMTOKEN).freeze,
      domain: "rdfa:TermMapping".freeze,
      label: "term".freeze,
      type: ["rdf:Property".freeze, "owl:DatatypeProperty".freeze]
    __property__ :uri,
      comment: %(defines the URI for either a prefix or a term mapping; the value is supposed to be an absolute URI).freeze,
      "dc:description" => %(defines the URI for either a prefix or a term mapping; the value is supposed to be an absolute URI).freeze,
      domain: "rdfa:PrefixOrTermMapping".freeze,
      label: "uri".freeze,
      type: ["rdf:Property".freeze, "owl:DatatypeProperty".freeze]
    __property__ :usesVocabulary,
      comment: %(provides a relationship between the host document and a vocabulary defined using the @vocab facility of RDFa1.1).freeze,
      "dc:description" => %(provides a relationship between the host document and a vocabulary defined using the @vocab facility of RDFa1.1).freeze,
      label: "usesVocabulary".freeze,
      type: ["rdf:Property".freeze, "owl:ObjectProperty".freeze]
    __property__ :vocabulary,
      comment: %(defines an absolute URI to be used as a default vocabulary; the value is can be any string; for documentation purposes it is advised to use the string 'true' or 'True'.).freeze,
      "dc:description" => %(defines an absolute URI to be used as a default vocabulary; the value is can be any string; for documentation purposes it is advised to use the string 'true' or 'True'.).freeze,
      label: "vocabulary".freeze,
      type: ["rdf:Property".freeze, "owl:DatatypeProperty".freeze]

    # Extra definitions
    __property__ :"",
      "dc:creator" => %(http://www.ivan-herman.net/foaf#me).freeze,
      "dc:date" => %(2013-01-18).freeze,
      "dc:description" => %(This document describes the RDFa Vocabulary for Term and Prefix Assignment. The Vocabulary is used to modify RDFa 1.1 processing behavior.).freeze,
      "dc:publisher" => %(http://www.w3.org/data#W3C).freeze,
      "dc:title" => %(RDFa Vocabulary for Term and Prefix Assignment, and for Processor Graph Reporting).freeze,
      label: "".freeze,
      "owl:versionInfo" => %($Date: 2013-03-11 07:54:23 $).freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/TR/rdfa-core/#s_initialcontexts).freeze,
      type: "owl:Ontology".freeze
  end

  class XML < Vocabulary("http://www.w3.org/XML/1998/namespace"); end
  class XSI < Vocabulary("http://www.w3.org/2001/XMLSchema-instance"); end
end
