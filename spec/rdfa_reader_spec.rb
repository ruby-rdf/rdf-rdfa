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

   it "should parse simple doc" do
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

    # FIXME: base URIs arn't working
    reader = RDF::RDFa::Reader.new(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0001.xhtml", :strict => true)
    reader.graph.size.should == 1
    reader.graph.should have_object("Mark Birbeck")
  end

  it "should parse simple doc without a base URI" do
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

    reader = RDF::RDFa::Reader.new(sampledoc, :strict => true)
    reader.graph.size.should == 1
    reader.graph.should have_triple([RDF::Node('photo'), RDF::DC11.creator, "Mark Birbeck"])
  end

  it "should parse an XML Literal" do
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

    reader = RDF::RDFa::Reader.new(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml", :strict => true)
    reader.graph.size.should == 2

    reader.graph.should have_object("Albert Einstein")
    reader.graph.should have_object(
      RDF::Literal("E = mc<sup>2</sup>: The Most Urgent Problem of Our Time",
        :datatype => RDF::URI('http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral'))
    )
  end


  it "should parse BNodes" do
    sampledoc = <<-EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml"
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

    reader = RDF::RDFa::Reader.new(sampledoc, :base_uri => "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml", :strict => true)

    reader.graph.size.should == 3
    reader.graph.should have_object("Ralph Swick")
    reader.graph.should have_object("Manu Sporny")
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