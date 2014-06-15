# -*- encoding: utf-8 -*-
module RDF
  class PTR < Vocabulary("http://www.w3.org/2009/pointers#")
    # Class definitions
    term :ByteOffsetCompoundPointer,
      comment: %(Pointer to a byte range with a defined start and a byte offset from there.).freeze,
      label: "Byte Offset Compound Pointer".freeze,
      subClassOf: "ptr:CompoundPointer".freeze,
      type: "rdfs:Class".freeze
    term :ByteOffsetPointer,
      comment: %(Single pointer using a byte offset from the start of the reference.).freeze,
      label: "Byte Offset Pointer".freeze,
      subClassOf: "ptr:OffsetPointer".freeze,
      type: "rdfs:Class".freeze
    term :ByteSnippetCompoundPointer,
      comment: %(Pointer to a range with a defined start and a byte snippet from there.).freeze,
      label: "Byte Snippet Compound Pointer".freeze,
      subClassOf: "ptr:CompoundPointer".freeze,
      type: "rdfs:Class".freeze
    term :CSSSelectorPointer,
      comment: %(Single pointer using a CSS selector.).freeze,
      label: "CSS selector Pointer".freeze,
      subClassOf: "ptr:ExpressionPointer".freeze,
      type: "rdfs:Class".freeze
    term :CharOffsetCompoundPointer,
      comment: %(Pointer to a char range with a defined start and a char offset from there.).freeze,
      label: "Char Offset Compound Pointer".freeze,
      subClassOf: "ptr:CompoundPointer".freeze,
      type: "rdfs:Class".freeze
    term :CharOffsetPointer,
      comment: %(Single pointer using a character offset from the start of the reference.).freeze,
      label: "Char Offset Pointer".freeze,
      subClassOf: "ptr:OffsetPointer".freeze,
      type: "rdfs:Class".freeze
    term :CharSnippetCompoundPointer,
      comment: %(Pointer to a range with a defined start and a character snippet from there.).freeze,
      label: "Char Snippet Compound Pointer".freeze,
      subClassOf: "ptr:CompoundPointer".freeze,
      type: "rdfs:Class".freeze
    term :CompoundPointer,
      comment: %(An abstract method made of a pair of pointers to a defined section to be subclassed for extensibility.).freeze,
      label: "Compound Pointer".freeze,
      subClassOf: "ptr:Pointer".freeze,
      type: "rdfs:Class".freeze
    term :EquivalentPointers,
      comment: %(Group of equivalent pointers that point to the same places.).freeze,
      label: "Equivalent Pointers".freeze,
      subClassOf: "ptr:PointersGroup".freeze,
      type: "rdfs:Class".freeze
    term :ExpressionPointer,
      comment: %(Generic single pointer that make use of an expression language such as xPath, CSS selectors, etc.).freeze,
      label: "Expression Pointer".freeze,
      subClassOf: "ptr:SinglePointer".freeze,
      type: "rdfs:Class".freeze
    term :LineCharPointer,
      comment: %(Single pointer using line and char numbers.).freeze,
      label: "Line-Char Pointer".freeze,
      subClassOf: "ptr:SinglePointer".freeze,
      type: "rdfs:Class".freeze
    term :OffsetPointer,
      comment: %(Generic single pointer based on an offset.).freeze,
      label: "Offset Pointer".freeze,
      subClassOf: "ptr:SinglePointer".freeze,
      type: "rdfs:Class".freeze
    term :Pointer,
      comment: %(Abstract Pointer to be subclassed for extensibility.).freeze,
      label: "Pointer".freeze,
      type: "rdfs:Class".freeze
    term :PointersGroup,
      comment: %(Generic container for a group of Pointers).freeze,
      label: "Pointers Group".freeze,
      subClassOf: "ptr:Pointer".freeze,
      type: "rdfs:Class".freeze
    term :RelatedPointers,
      comment: %(Group of related pointers you use together for some purpose.).freeze,
      label: "Related Pointers".freeze,
      subClassOf: "ptr:PointersGroup".freeze,
      type: "rdfs:Class".freeze
    term :SinglePointer,
      comment: %(Abstract pointer to a single point to be subclassed for extensibility.).freeze,
      label: "Single Pointer".freeze,
      subClassOf: "ptr:Pointer".freeze,
      type: "rdfs:Class".freeze
    term :StartEndPointer,
      comment: %(Compound pointer to a range with a start and an end point.).freeze,
      label: "Start-End Pointer".freeze,
      subClassOf: "ptr:CompoundPointer".freeze,
      type: "rdfs:Class".freeze
    term :XMLNamespace,
      comment: %(An XML Namespace.).freeze,
      label: "XMLNamespace".freeze,
      type: "rdfs:Class".freeze
    term :XPathPointer,
      comment: %(Single pointer using an XPath expression.).freeze,
      label: "XPath Pointer".freeze,
      subClassOf: "ptr:ExpressionPointer".freeze,
      type: "rdfs:Class".freeze
    term :XPointerPointer,
      comment: %(Single pointer using an XPointer expression.).freeze,
      label: "XPointer Pointer".freeze,
      subClassOf: "ptr:XPathPointer".freeze,
      type: "rdfs:Class".freeze

    # Property definitions
    property :byteOffset,
      comment: %(Number of bytes counting from the start point.).freeze,
      domain: "ptr:ByteOffsetCompoundPointer".freeze,
      label: "byte offset".freeze,
      range: "xsd:positiveInteger".freeze,
      type: "rdf:Property".freeze
    property :charNumber,
      comment: %(Char number within a line starting at one.
		).freeze,
      domain: "ptr:LineCharPointer".freeze,
      label: "char number".freeze,
      range: "xsd:positiveInteger".freeze,
      type: "rdf:Property".freeze
    property :charOffset,
      comment: %(Number of characters counting from the start point.).freeze,
      domain: "ptr:CharOffsetCompoundPointer".freeze,
      label: "char offset".freeze,
      range: "xsd:positiveInteger".freeze,
      type: "rdf:Property".freeze
    property :endPointer,
      comment: %(Pointer to the end point of the range.).freeze,
      domain: "ptr:StartEndPointer".freeze,
      label: "end pointer".freeze,
      range: "ptr:SinglePointer".freeze,
      type: "rdf:Property".freeze
    property :expression,
      comment: %(Expressions, such as xPath or CSS selectors, that identify points.).freeze,
      domain: "ptr:ExpressionPointer".freeze,
      label: "expression".freeze,
      range: "rdfs:Literal".freeze,
      type: "rdf:Property".freeze
    property :groupPointer,
      comment: %(A Pointer that is part of a Group).freeze,
      domain: "ptr:PointersGroup".freeze,
      label: "groupPointer".freeze,
      range: "ptr:Pointer".freeze,
      type: "rdf:Property".freeze
    property :lineNumber,
      comment: %(Line number within the reference starting at one.
		).freeze,
      domain: "ptr:LineCharPointer".freeze,
      label: "line number".freeze,
      range: "xsd:positiveInteger".freeze,
      type: "rdf:Property".freeze
    property :namespace,
      comment: %(The namespace being used for the XPath expression.).freeze,
      domain: "ptr:XPathPointer".freeze,
      label: "namespace".freeze,
      range: "ptr:XMLNamespace".freeze,
      type: "rdf:Property".freeze
    property :namespaceName,
      comment: %(The namespace name being used for an XML Namespace.).freeze,
      domain: "ptr:XMLNamespace".freeze,
      label: "namespace name".freeze,
      type: "rdf:Property".freeze
    property :offset,
      comment: %(Offset from the start of the reference.).freeze,
      domain: "ptr:OffsetPointer".freeze,
      label: "offset".freeze,
      range: "xsd:positiveInteger".freeze,
      type: "rdf:Property".freeze
    property :prefix,
      comment: %(The namespace prefix being used for an XML Namespace.).freeze,
      domain: "ptr:XMLNamespace".freeze,
      label: "prefix".freeze,
      type: "rdf:Property".freeze
    property :reference,
      comment: %(Scope within which a single pointer operates.).freeze,
      domain: "ptr:SinglePointer".freeze,
      label: "reference".freeze,
      type: "rdf:Property".freeze
    property :startPointer,
      comment: %(Pointer to the start point of the range in a compound pointer.).freeze,
      domain: "ptr:CompoundPointer".freeze,
      label: "start pointer".freeze,
      range: "ptr:SinglePointer".freeze,
      type: "rdf:Property".freeze
    property :version,
      comment: %(Version for the expression language being used.).freeze,
      domain: "ptr:ExpressionPointer".freeze,
      label: "version".freeze,
      range: "rdfs:Literal".freeze,
      type: "rdf:Property".freeze
  end

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
