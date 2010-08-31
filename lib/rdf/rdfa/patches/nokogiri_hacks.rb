require 'nokogiri'
class Nokogiri::XML::Node
  # URI of namespace + node_name
  def uri
    ns = self.namespace ? self.namespace.href : RDF::XML.to_s
    RDF::URI.intern(ns + self.node_name)
  end

  def display_path
    @display_path ||= case self
    when Nokogiri::XML::Document then ""
    when Nokogiri::XML::Element then parent ? "#{parent.display_path}/#{name}" : name
    when Nokogiri::XML::Attr then "#{parent.display_path}@#{name}"
    end
  end
end
