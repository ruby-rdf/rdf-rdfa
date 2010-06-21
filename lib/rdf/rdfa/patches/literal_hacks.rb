module RDF
  class Literal
    # Support for XML Literals
    # Is this an XMLLiteral?
    def xmlliteral?
      datatype == RDF['XMLLiteral']
    end
    
    def anonymous?; false; end unless respond_to?(:anonymous?)
    
    ##
    # Returns a string representation of this literal.
    #
    # @return [String]
    def to_s
      quoted = value # FIXME
      output = "\"#{quoted}\""
      output << "@#{language}" if has_language? && !has_datatype?
      output << "^^<#{datatype}>" if has_datatype?
      output
    end
    
    # Normalize an XML Literal, by adding necessary namespaces.
    # This should be done as part of initialize
    #
    # namespaces is a hash of prefix => URIs
    def self.xmlliteral(contents, options = {})
      options[:namespaces] ||= {}
      l = new("", :datatype => RDF["XMLLiteral"])

      if contents.is_a?(String)
        ns_hash = {}
        options[:namespaces].each_pair do |prefix, uri|
          attr = prefix.to_s.empty? ? "xmlns" : "xmlns:#{prefix}"
          ns_hash[attr] = uri.to_s
        end
        ns_strs = []
        ns_hash.each_pair {|a, u| ns_strs << "#{a}=\"#{u}\""}

        # Add inherited namespaces to created root element so that they're inherited to sub-elements
        contents = Nokogiri::XML::Document.parse("<foo #{ns_strs.join(" ")}>#{contents}</foo>").root.children
      end

      # Add already mapped namespaces and language
      l.value = contents.map do |c|
        if c.is_a?(Nokogiri::XML::Element)
          c = Nokogiri::XML.parse(c.dup.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS)).root
          # Gather namespaces from self and decendant nodes
          c.traverse do |n|
            ns = n.namespace
            next unless ns
            prefix = ns.prefix ? "xmlns:#{ns.prefix}" : "xmlns"
            c[prefix] = ns.href.to_s unless c.namespaces[prefix]
          end
          
          # Add lanuage
          if options[:language] && c["lang"].to_s.empty?
            c["xml:lang"] = options[:language]
          end
        end
        c.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS)
      end.join("")
      l
    end
  end
end