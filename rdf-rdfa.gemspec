#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = %q{rdf-rdfa}
  gem.homepage              = "https://github.com/ruby-rdf/rdf-rdfa"
  gem.license               = 'Unlicense'
  gem.summary               = "RDFa reader/writer for RDF.rb."
  gem.description           = "RDF::RDFa is an RDFa reader/writer for Ruby using the RDF.rb library suite."

  gem.authors               = %w(Gregg Kellogg)
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README.md UNLICENSE VERSION) + Dir.glob('lib/**/*.rb')
  gem.require_paths         = %w(lib)

  gem.required_ruby_version = '>= 2.4'
  gem.requirements          = []

  gem.add_runtime_dependency     'rdf',                 '~> 3.1', '>= 3.1.12'
  gem.add_runtime_dependency     'rdf-vocab',           '~> 3.1', '>= 3.1.11'
  gem.add_runtime_dependency     'haml',                '~> 5.2'
  gem.add_runtime_dependency     'rdf-xsd',             '~> 3.1'
  gem.add_runtime_dependency     'rdf-aggregate-repo',  '~> 3.1'
  gem.add_runtime_dependency     'htmlentities',        '~> 4.3'

  gem.add_development_dependency 'json-ld',             '~> 3.1'
  gem.add_development_dependency 'rspec',               '~> 3.10'
  gem.add_development_dependency 'rspec-its',           '~> 1.3'
  gem.add_development_dependency 'rdf-spec',            '~> 3.1'
  gem.add_development_dependency 'rdf-turtle',          '~> 3.1'
  gem.add_development_dependency 'rdf-isomorphic',      '~> 3.1'
  gem.add_development_dependency 'rdf-tabular',         '~> 3.1'
  gem.add_development_dependency 'rdf-rdfxml',          '~> 3.1'
  gem.add_development_dependency 'sparql',              '~> 3.1'
  gem.add_development_dependency 'yard' ,               '~> 0.9'

  gem.post_install_message  = nil
end

