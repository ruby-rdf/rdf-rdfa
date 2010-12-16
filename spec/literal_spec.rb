# coding: utf-8
$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDF::Literal do
  require 'nokogiri' rescue nil

  before :each do 
    @new = Proc.new { |*args| RDF::Literal.new(*args) }
  end

  describe "XML Literal" do
    describe "with no namespace" do
      subject { @new.call("foo <sup>bar</sup> baz!", :datatype => RDF.XMLLiteral) }
      it "should return input" do subject.to_s.should == "foo <sup>bar</sup> baz!" end

      it "should be equal if they have the same contents" do
        should == @new.call("foo <sup>bar</sup> baz!", :datatype => RDF.XMLLiteral)
      end
    end

    describe "with a namespace" do
      subject {
        @new.call("foo <dc:sup>bar</dc:sup> baz!", :datatype => RDF.XMLLiteral,
                      :namespaces => {:dc => RDF::DC.to_s})
      }

      it "should add namespaces" do subject.to_s.should == "foo <dc:sup xmlns:dc=\"http://purl.org/dc/terms/\">bar</dc:sup> baz!" end

        describe "as string prefix" do
          subject {
            @new.call("foo <dc:sup>bar</dc:sup> baz!", :datatype => RDF.XMLLiteral,
                          :namespaces => {"dc" => RDF::DC.to_s})
          }

          it "should add namespaces" do subject.to_s.should == "foo <dc:sup xmlns:dc=\"http://purl.org/dc/terms/\">bar</dc:sup> baz!" end
        end

      describe "and language" do
        subject {
          @new.call("foo <dc:sup>bar</dc:sup> baz!", :datatype => RDF.XMLLiteral,
                        :namespaces => {:dc => RDF::DC.to_s},
                        :language => :fr)
        }

        it "should add namespaces and language" do subject.to_s.should == "foo <dc:sup xmlns:dc=\"http://purl.org/dc/terms/\" xml:lang=\"fr\">bar</dc:sup> baz!" end
      end

      describe "and node set" do
        subject {
          root = Nokogiri::XML.parse(%(<?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
          <html xmlns="http://www.w3.org/1999/xhtml"
                xmlns:dc="http://purl.org/dc/terms/"
                xmlns:ex="http://example.org/rdf/"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:svg="http://www.w3.org/2000/svg">
            <head profile="http://www.w3.org/1999/xhtml/vocab http://www.w3.org/2005/10/profile">
              <title>Test 0100</title>
            </head>
            <body>
              <div about="http://www.example.org">
                <h2 property="ex:example" datatype="rdf:XMLLiteral"><svg:svg/></h2>
              </div>
            </body>
          </html>
          ), nil, nil, Nokogiri::XML::ParseOptions::DEFAULT_XML).root
          content = root.css("h2").children
          @new.call(content, :datatype => RDF.XMLLiteral,
                    :namespaces => {
                      :svg => "http://www.w3.org/2000/svg",
                      :dc => "http://purl.org/dc/terms/",
                    })
        }
        it "should add namespace" do subject.to_s.should == "<svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\" xmlns:dc=\"http://purl.org/dc/terms/\"></svg:svg>" end
      end

      describe "and language with an existing language embedded" do
        subject {
          @new.call("foo <dc:sup>bar</dc:sup><dc:sub xml:lang=\"en\">baz</dc:sub>",
                        :datatype => RDF.XMLLiteral,
                        :namespaces => {:dc => RDF::DC.to_s},
                        :language => :fr)
        }

        it "should add namespaces and language" do subject.to_s.should == "foo <dc:sup xmlns:dc=\"http://purl.org/dc/terms/\" xml:lang=\"fr\">bar</dc:sup><dc:sub xmlns:dc=\"http://purl.org/dc/terms/\" xml:lang=\"en\">baz</dc:sub>" end
      end
    end

    describe "with a default namespace" do
      subject {
        @new.call("foo <sup>bar</sup> baz!", :datatype => RDF.XMLLiteral,
                      :namespaces => {"" => RDF::DC.to_s})
      }

      it "should add namespace" do subject.to_s.should == "foo <sup xmlns=\"http://purl.org/dc/terms/\">bar</sup> baz!" end
    end

    describe "with a default namespace (as empty string)" do
      subject {
        @new.call("foo <sup>bar</sup> baz!", :datatype => RDF.XMLLiteral,
                      :namespaces => {"" => RDF::DC.to_s})
      }

      it "should add namespace" do subject.to_s.should == "foo <sup xmlns=\"http://purl.org/dc/terms/\">bar</sup> baz!" end
    end

    context "rdfcore tests" do
      context "rdfms-xml-literal-namespaces" do
        it "should reproduce test001" do
          l = @new.call("
      <html:h1>
        <b>John</b>
      </html:h1>
   ",
                      :datatype => RDF.XMLLiteral,
                      :namespaces => {
                        "" => "http://www.w3.org/1999/xhtml",
                        "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
                        "html" => "http://NoHTML.example.org",
                        "my" => "http://my.example.org/",
                      })

          pending do
            l.to_s.should == "\n      <html:h1 xmlns:html=\"http://NoHTML.example.org\">\n        <b xmlns=\"http://www.w3.org/1999/xhtml\">John</b>\n      </html:h1>\n   "
          end
        end

        it "should reproduce test002" do
          l = @new.call("
    Ramifications of
       <apply>
      <power/>
      <apply>
	<plus/>
	<ci>a</ci>
	<ci>b</ci>
      </apply>
      <cn>2</cn>
    </apply>
    to World Peace
  ",
                      :datatype => RDF.XMLLiteral,
                      :namespaces => {
                        "" => "http://www.w3.org/TR/REC-mathml",
                      })

          l.to_s.should == "\n    Ramifications of\n       <apply xmlns=\"http://www.w3.org/TR/REC-mathml\">\n      <power></power>\n      <apply>\n\t<plus></plus>\n\t<ci>a</ci>\n\t<ci>b</ci>\n      </apply>\n      <cn>2</cn>\n    </apply>\n    to World Peace\n  "
        end
      end

      context "rdfms-xmllang" do
        it "should reproduce test001" do
          l = @new.call("chat", :datatype => RDF.XMLLiteral, :language => nil)

          l.to_s.should == "chat"
        end
        it "should reproduce test002" do
          l = @new.call("chat", :datatype => RDF.XMLLiteral, :language => :fr)

          l.to_s.should == "chat"
        end
      end

      context "xml-canon" do
        it "should reproduce test001" do
          l = @new.call("<br />", :datatype => RDF.XMLLiteral)

          l.to_s.should == "<br></br>"
        end
      end
    end

    context "rdfa tests" do
      it "should reproduce test 0011: XMLLiteral" do
        l = @new.call("E = mc<sup>2</sup>: The Most Urgent Problem of Our Time",
                    :datatype => RDF.XMLLiteral,
                    :namespaces => {"" => "http://www.w3.org/1999/xhtml"})

        l.to_s.should == "E = mc<sup xmlns=\"http://www.w3.org/1999/xhtml\">2</sup>: The Most Urgent Problem of Our Time"
      end

      it "should reproduce test 0092: Tests XMLLiteral content with explicit @datatype" do
        l = @new.call(%(E = mc<sup>2</sup>: The Most Urgent Problem of Our Time<),
                    :datatype => RDF.XMLLiteral,
                    :namespaces => {"" => "http://www.w3.org/1999/xhtml"})

        l.to_s.should == "E = mc<sup xmlns=\"http://www.w3.org/1999/xhtml\">2</sup>: The Most Urgent Problem of Our Time"
      end

      it "should reproduce test 0100: XMLLiteral with explicit namespace" do
        l = @new.call(%(Some text here in <strong>bold</strong> and an svg rectangle: <svg:svg><svg:rect svg:width="200" svg:height="100"/></svg:svg>),
                    :datatype => RDF.XMLLiteral,
                    :namespaces => {
                      "" => "http://www.w3.org/1999/xhtml",
                      "svg" => "http://www.w3.org/2000/svg",
                    })

        pending do
          l.to_s.should == "Some text here in <strong xmlns=\"http://www.w3.org/1999/xhtml\">bold</strong> and an svg rectangle: <svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\"><svg:rect svg:height=\"100\" svg:width=\"200\"></svg:rect></svg:svg>"
        end
      end

      it "should reproduce 0101: XMLLiteral with explicit namespace and xml:lang" do
        l = @new.call(%(Du texte ici en <strong>gras</strong> et un rectangle en svg: <svg:svg><svg:rect svg:width="200" svg:height="100"/></svg:svg>),
                    :datatype => RDF.XMLLiteral, :language => :fr,
                    :namespaces => {
                      "" => "http://www.w3.org/1999/xhtml",
                      "svg" => "http://www.w3.org/2000/svg",
                    })

        pending do
          l.to_s.should == "Du texte ici en <strong xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"fr\">gras</strong> et un rectangle en svg: <svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\" xml:lang=\"fr\"><svg:rect svg:height=\"100\" svg:width=\"200\"></svg:rect></svg:svg>"
        end
      end

      it "should reproduce test 0102: XMLLiteral with explicit namespace and xml:lang; not overwriting existing langs" do
        l = @new.call(%(Du texte ici en <strong>gras</strong> et un rectangle en svg: <svg:svg xml:lang="hu"><svg:rect svg:width="200" svg:height="100"/></svg:svg>),
                    :datatype => RDF.XMLLiteral, :language => :fr,
                    :namespaces => {
                      "" => "http://www.w3.org/1999/xhtml",
                      "svg" => "http://www.w3.org/2000/svg",
                    })

        pending do
          l.to_s.should == "Du texte ici en <strong xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"fr\">gras</strong> et un rectangle en svg: <svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\" xml:lang=\"hu\"><svg:rect svg:height=\"100\" svg:width=\"200\"></svg:rect></svg:svg>"
        end
      end

      it "should reproduce test 0103: XMLLiteral with explicit namespace; not overwriting local namespaces" do
        l = @new.call(%(Some text here in <strong>bold</strong> and an svg rectangle: <svg xmlns="http://www.w3.org/2000/svg"><rect width="200" height="100"/></svg>),
                    :datatype => RDF.XMLLiteral,
                    :namespaces => {
                      "" => "http://www.w3.org/1999/xhtml",
                      "svg" => "http://www.w3.org/2000/svg",
                    })

        pending do
          l.to_s.should == "Some text here in <strong xmlns=\"http://www.w3.org/1999/xhtml\">bold</strong> and an svg rectangle: <svg xmlns=\"http://www.w3.org/2000/svg\"><rect height=\"100\" width=\"200\"></rect></svg>"
        end
      end
    end
  end if defined?(::Nokogiri)
end
