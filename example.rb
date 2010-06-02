#!/usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'rubygems'
require 'rdfa/reader'

data = <<-EOF;
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

$DEBUG = false

reader = RDFa::Reader.new(data, :debug => false)
reader.each_statement do |statement|
  statement.inspect!
end
