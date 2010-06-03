require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDF::RDFa::Format do
  it "should be discoverable" do
    formats = [
      RDF::Format.for(:rdfa),
      RDF::Format.for("etc/foaf.html"),
      RDF::Format.for(:file_name      => "etc/foaf.html"),
      RDF::Format.for(:file_extension => "html"),
      RDF::Format.for(:file_extension => "xhtml"),
      RDF::Format.for(:content_type   => "text/html"),
      RDF::Format.for(:content_type   => "application/xhtml+xml"),
    ]
    formats.each { |format| format.should == RDF::RDFa::Format }
  end
end

describe "RDF::RDFa::Reader" do
  it "should be discoverable" do
    readers = [
      RDF::Reader.for(:rdfa),
      RDF::Reader.for("etc/foaf.html"),
      RDF::Reader.for(:file_name      => "etc/foaf.html"),
      RDF::Reader.for(:file_extension => "html"),
      RDF::Reader.for(:file_extension => "xhtml"),
      RDF::Reader.for(:content_type   => "text/html"),
      RDF::Reader.for(:content_type   => "application/xhtml+xml"),
    ]
    readers.each { |reader| reader.should == RDF::RDFa::Reader }
  end

  context "paring a simple doc" do
    before :each do
      sampledoc = <<-EOF;
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml"
            xmlns:dc="http://purl.org/dc/elements/1.1/">
      <head>
        <title>Test 0001</title>
      </head>
      <body>
        <p>This photo was taken by <span class="author" about="photo1.jpg" property="dc:creator">Mark Birbeck</span>.</p>
      </body>
      </html>
      EOF

      @reader = RDF::RDFa::Reader.new(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0001.xhtml", :strict => true)
      @statement = @reader.graph.statements.first
    end

    it "should return 1 triple" do
      @reader.graph.size.should == 1
    end

    it "should have a subject with an expanded URI" do
      @statement.subject.should == RDF::URI('http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/photo1.jpg')
    end

    it "should have a predicate of dc:creator" do
      @statement.predicate.should == RDF::DC11.creator
    end

    it "should have an object of type literal and value 'Mark Birkbeck'" do
      @statement.object.should == RDF::Literal("Mark Birbeck")
    end
  end

  context "parsing a simple doc without a base URI" do
    before :each do
      sampledoc = <<-EOF;
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml"
            xmlns:dc="http://purl.org/dc/elements/1.1/">
      <body>
        <p>This photo was taken by <span class="author" about="_:photo" property="dc:creator">Mark Birbeck</span>.</p>
      </body>
      </html>
      EOF

      @reader = RDF::RDFa::Reader.new(sampledoc, :strict => true)
      @statement = @reader.graph.statements.first
    end

    it "should return 1 triple" do
      @reader.graph.size.should == 1
    end

    it "should have a Blank Node named 'photo' as the subject of the triple" do
      @statement.subject.should == RDF::Node('photo')
    end

    it "should have a predicate of dc:creator" do
      @statement.predicate.should == RDF::DC11.creator
    end

    it "should have an object of type literal and value 'Mark Birkbeck'" do
      @statement.object.should == RDF::Literal("Mark Birbeck")
    end
  end

  context "parsing a document containing an XML Literal" do
    before :each do
      sampledoc = <<-EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml"
            xmlns:dc="http://purl.org/dc/elements/1.1/">
        <head>
          <title>Test 0011</title>
        </head>
        <body>
          <div about="">
            Author: <span property="dc:creator">Albert Einstein</span>
            <h2 property="dc:title">E = mc<sup>2</sup>: The Most Urgent Problem of Our Time</h2>
        </div>
        </body>
      </html>
      EOF

      @reader = RDF::RDFa::Reader.new(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml", :strict => true)
    end

    it "should return 2 triples" do
      @reader.graph.size.should == 2
    end

    it "should have a triple for the dc:creator of the document" do
      @reader.graph.should have_triple([
        RDF::URI('http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml'),
        RDF::DC11.creator,
        "Albert Einstein"
      ])
    end

    it "should have an XML Literal for the dc:title of the document" do
      @reader.graph.should have_triple([
        RDF::URI('http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml'),
        RDF::DC11.title,
        RDF::Literal("E = mc<sup>2</sup>: The Most Urgent Problem of Our Time", :datatype => RDF.XMLLiteral)
      ])
    end
  end

  context "parsing a document containing sereral bnodes" do
    before :each do
      sampledoc = <<-EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.0"
            xmlns:foaf="http://xmlns.com/foaf/0.1/">
        <head>
        <title>Test 0017</title>
        </head>
        <body>
           <p>
                <span about="[_:a]" property="foaf:name">Manu Sporny</span>
                 <span about="[_:a]" rel="foaf:knows" resource="[_:b]">knows</span>
                 <span about="[_:b]" property="foaf:name">Ralph Swick</span>.
              </p>
        </body>
      </html>
      EOF

      @reader = RDF::RDFa::Reader.new(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0017.xhtml", :strict => true)
    end

    it "should return 3 triples" do
      @reader.graph.size.should == 3
    end

    it "should have a triple for the foaf:name of BNode A" do
      @reader.graph.should have_triple([
        RDF::Node('a'),
        RDF::FOAF.name,
        "Manu Sporny"
      ])
    end

    it "should have a triple for the foaf:name of BNode B" do
      @reader.graph.should have_triple([
        RDF::Node('b'),
        RDF::FOAF.name,
        "Ralph Swick"
      ])
    end

    it "should have a triple for BNode A knows BNode B" do
      @reader.graph.should have_triple([
        RDF::Node('a'),
        RDF::FOAF.knows,
        RDF::Node('b'),
      ])
    end
  end


  context "parsing a document that uses the typeof attribute" do
    before :each do
      sampledoc = <<-EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.0"
            xmlns:foaf="http://xmlns.com/foaf/0.1/">
        <head>
          <title>Test 0049</title>
        </head>
        <body>
          <div about="http://www.example.org/#me" typeof="foaf:Person">
            <p property="foaf:name">John Doe</p>
          </div>
        </body>
      </html>
      EOF

      @reader = RDF::RDFa::Reader.new(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0049.xhtml", :strict => true)
    end

    it "should return 2 triples" do
      @reader.graph.size.should == 2
    end

    it "should have a triple stating that #me is of type foaf:Person" do
      @reader.graph.should have_triple([
        RDF::URI('http://www.example.org/#me'),
        RDF.type,
        RDF::FOAF.Person
      ])
    end

    it "should have a triple stating that #me has name 'John Doe'" do
      @reader.graph.should have_triple([
        RDF::URI('http://www.example.org/#me'),
        RDF::FOAF.name,
        RDF::Literal("John Doe")
      ])
    end
  end

  def self.test_cases(suite)
     [] #RdfaHelper::TestCase.test_cases(suite)
  end

  # W3C Test suite from http://www.w3.org/2006/07/SWD/RDFa/testsuite/
  %w(xhtml html4 html5).each do |suite|
    describe "w3c #{suite} testcases" do
      describe "that are approved" do
        test_cases(suite).each do |t|
          puts t.inspect
          next unless t.status == "approved"
          #next unless t.name =~ /0140/
          specify "test #{t.name}: #{t.title}#{",  (negative test)" unless t.expectedResults}" do
            #puts t.input
            #puts t.results
            begin
              t.run_test do |rdfa_string, rdfa_parser|
                rdfa_parser.parse(rdfa_string, t.informationResourceInput, :debug => [])
              end
            rescue SparqlException => e
              pending(e.message) { raise }
            end
          end
        end
      end
      describe "that are unreviewed" do
        test_cases(suite).each do |t|
          next unless t.status == "unreviewed"
          #next unless t.name =~ /0185/
          #puts t.inspect
          specify "test #{t.name}: #{t.title}#{",  (negative test)" unless t.expectedResults}" do
            begin
              t.run_test do |rdfa_string, rdfa_parser|
                rdfa_parser.parse(rdfa_string, t.informationResourceInput, :debug => [])
              end
            rescue SparqlException => e
              pending(e.message) { raise }
            rescue Spec::Expectations::ExpectationNotMetError => e
              if t.name =~ /01[789]\d/
                raise
              else
                pending() {  raise }
              end
            end
          end
        end
      end
   end
 end
end
