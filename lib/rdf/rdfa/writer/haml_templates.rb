# Default HAML templates used for generating output from the writer
module RDF::RDFa
  class Writer
    # The default set of HAML templates used for RDFa code generation
    DEFAULT_HAML = {
      # Document
      # Locals: language, title, profile, prefix, base, subjects
      # Yield: subjects.each
      :doc => %q(
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
      ),

      # Output for non-leaf resources
      # Note that @about may be omitted for Nodes that are not referenced
      #
      # Locals: about, typeof, predicates
      # Yield: predicates.each
      :subject => %q(
        %div{:about => about, :typeof => typeof}
          - if typeof
            = "#{about || Something} with type #{typeof}"
          - predicates.each do |predicate|
            != yield(predicate)
      ),

      # Output for single-valued properties
      # Locals: property, objects
      # Yields: object
      # If nil is returned, render as a leaf
      # Otherwise, render result
      :property_value => %q(
        - object = objects.first
        - if heading_predicates.include?(predicate) && object.literal?
          %h1{:property => get_curie(predicate), :content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object)}&= get_value(object)
        - else
          %div.property
            %span.label
              = get_predicate_name(predicate)
            - if res = yield(object)
              %div{:rel => get_curie(rel)}
                != res
            - elsif object.node?
              %span{:resource => get_curie(object), :rel => get_curie(predicate)}= get_curie(object)
            - elsif object.uri?
              %a{:href => object.to_s, :rel => get_curie(predicate)}= object.to_s
            - elsif object.datatype == RDF.XMLLiteral
              %span{:property => get_curie(predicate), :lang => get_lang(object), :datatype => get_dt_curie(object)}<!= get_value(object)
            - else
              %span{:property => get_curie(predicate), :content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object)}&= get_value(object)
      ),

      # Output for multi-valued properties
      # Locals: property, rel, :objects
      # Yields: object for leaf resource rendering
      :property_values =>  %q(
        %div.property
          %span.label
            = get_predicate_name(predicate)
          %ul{:rel => (get_curie(rel) if rel), :property => (get_curie(property) if property)}
            - objects.each do |object|
              - if res = yield(object)
                %li
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
      ),
    }

    # An alternative, minimal HAML template for RDFa code generation.
    # This version does not perform recursive object generation and does not attempt
    # to create human readable output.
    MIN_HAML = {
      # Document
      # Locals: language, title, profile, prefix, base, subjects
      # Yield: subjects.each
      :doc => %q(
        !!! XML
        !!! 5
        %html{:xmlns => "http://www.w3.org/1999/xhtml", :lang => lang, :profile => profile, :prefix => prefix}
          - if base
            %head
              %base{:href => base}
          %body
            - subjects.each do |subject|
              != yield(subject)
      ),

      # Output for non-leaf resources
      # Note that @about may be omitted for Nodes that are not referenced
      #
      # Locals: about, typeof, predicates
      # Yield: predicates.each
      :subject => %q(
        %div{:about => about, :typeof => typeof}
          - if typeof
            = "#{about || Something} with type #{typeof}"
          - predicates.each do |predicate|
            != yield(predicate)
      ),

      # Output for single-valued properties.
      # This version does not perform a recursive call, and renders all objects as leafs.
      # Locals: property, objects
      # Yields: object
      # If nil is returned, render as a leaf
      # Otherwise, render result
      :property_value => %q(
        - object = objects.first
        %div.property
          - if object.resource?
            %span{:resource => get_curie(object), :rel => get_curie(predicate)}
          - elsif object.datatype == RDF.XMLLiteral
            %span{:property => get_curie(predicate), :lang => get_lang(object), :datatype => get_dt_curie(object)}<!= get_value(object)
          - else
            %span{:property => get_curie(predicate), :lang => get_lang(object), :datatype => get_dt_curie(object)}&= object.to_s
      ),

      # Output for multi-valued properties.
      # This version does not perform a recursive call, and renders all objects as leafs.
      # Locals: property, rel, :objects
      # Yields: object for leaf resource rendering
      :property_values =>  %q(
        %div.property
          %ul{:rel => (get_curie(rel) if rel), :property => (get_curie(property) if property)}
            - objects.each do |object|
              - if object.resource?
                %li{:resource => get_curie(object)}
              - elsif object.datatype == RDF.XMLLiteral
                %li{:lang => get_lang(object), :datatype => get_curie(object.datatype)}<!= get_value(object)
              - else
                %li{:lang => get_lang(object), :datatype => get_dt_curie(object)}&= object.to_s
      ),
    }
  end
end