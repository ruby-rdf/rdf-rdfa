source "http://rubygems.org"

gemspec

gem "rdf",            :git => "git://github.com/ruby-rdf/rdf.git"
gem "rdf-spec",       :git => "git://github.com/ruby-rdf/rdf-spec.git"
gem "rdf-xsd",        :git => "git://github.com/ruby-rdf/rdf-xsd.git"
gem 'rdf-turtle',     :git => "git://github.com/ruby-rdf/rdf-turtle.git"
gem 'ebnf',           :git => "git://github.com/gkellogg/ebnf.git"
gem 'sparql',         :git => "git://github.com/ruby-rdf/sparql.git"
  
# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :debug do
  gem "wirble"
  gem "syntax"
  gem "debugger" if RUBY_VERSION == "1.9.3"
end
