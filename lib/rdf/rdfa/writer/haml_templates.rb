# Default HAML templates used for generating output from the writer
module RDF::RDFa
  class Writer
    DEFAULT_HAML = {
      # Detect media types for URI resources and render with appropriate HTML element
      :subject_template => {
        %r(\.(mp3|m4a)) => :audio_subject,
        %r(\.(jpg|png|svg|gif)) => :image_subject,
        %r(\.(mp4|m4v)) => :video_subject,
        %r(^_:) => :node_subject,
      },
      :object_template => {
#        %r(\.(mp3|m4a)) => :audio_resource,
#        %r(\.(jpg|png|svg|gif)) => :image_resource,
#        %r(\.(mp4|m4v)) => :video_resource,
        %r(^_:) => :node_resource,
      },

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

      # Output for literals treated as title, either singular or multiple
      # Locals: depth, property, datatype, language, content, value
      :heading_literal => %q(
        %h1{:property => property, :content => content, :lang => lang, :datatype => datatype}&= value
      ),

      # Output for literals, either singular or multiple
      # Locals: property, datatype, language, content, value
      :single_literal => %q(
        %div.property
          %span.label
            = property
          %span{:property => property, :content => content, :lang => lang, :datatype => datatype}&= value
      ),

      # Partial for multiple literals
      # Locals: datatype, language, content, value
      :_literal => %q(
        %li{:content => content, :lang => lang, :datatype => datatype}&= value
      ),

      # Template to use for XMLLiterals, based on translation from selected literal template key
      # Locals: datatype, language, content, value
      :xml_literal => {
        :single_literal => %q(
          %div.property
            %span.label
              = property
            %span{:property => property, :lang => lang, :datatype => datatype}<
              != value
        ),
        :_literal => %q(
          %li{:content => content, :lang => lang, :datatype => datatype}<
            != value
        )
      },

      # Output for resources, either singular or multiple
      # Locals: property, object
      # Yields: object for leaf resource rendering
      :single_resource => %q(
        %div.property
          %span.label
            = property
          != yield(object)
      ),

      # Output for multple resources, either URI/BNode or Literal
      # Locals: property, rel, :objects
      # Yields: object for leaf resource rendering
      :multiple_resource => 
        %q(
        %div.property
          %span.label
            = (property || rel)
          %ul{:rel => rel, :property => property}
            - objects.each do |object|
              != yield(object)
      ),

      # Output for non-leaf resources
      # Locals: about, resource, typeof, subject, predicates
      # Yield: predicates.each
      :default_subject => %q(
        %div{:about => about, :typeof => typeof}
          - if typeof
            = "#{about} with type #{typeof}"
          - predicates.each do |predicate|
            != yield(predicate)
      ),
      :audio_subject => %q(
        %div{:about => about, :typeof => typeof}
          - if typeof
            = "Audio with type #{typeof}"
          %audio{:src => subject.to_s}
          - predicates.each do |predicate|
            != yield(predicate)
      ),
      :image_subject => %q(
        %div{:about => about, :typeof => typeof}
          - if typeof
            = "Image with type #{typeof}"
          %img{:src => subject.to_s}
          - predicates.each do |predicate|
            != yield(predicate)
      ),
      :video_subject => %q(
        %div{:about => about, :typeof => typeof}
          - if typeof
            = "Video with type #{typeof}"
          %video{:src => subject.to_s}
          - predicates.each do |predicate|
            != yield(predicate)
      ),
      :anon_subject => %q(
        %div{:typeof => typeof || ""}
          - if typeof
            = "Something with type #{typeof}"
          - predicates.each do |predicate|
            != yield(predicate)
      ),
      :node_subject => %q(
        %div{:about => about, :typeof => typeof}
          - if typeof
            = "Something named #{about} with type #{typeof}"
          - predicates.each do |predicate|
            != yield(predicate)
      ),

      # Output for leaf resources
      # locals: object, curie
      :default_resource => %q(%a{:href => object.to_s, :rel => rel}= object.to_s),
      :audio_resource => %q(%audio{:src => object.to_s, :resource => curie, :rel => rel}),
      :image_resource => %q(%img{:src => object.to_s, :resource => curie, :rel => rel}),
      :video_resource => %q(%video{:src => object.to_s, :resource => curie, :rel => rel}),
      :node_resource => %q(%span{:resource => curie, :rel => rel}),
    }
  end
end