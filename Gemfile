source "http://rubygems.org"

gemspec

gem "rdf",            :git => "git://github.com/ruby-rdf/rdf.git", :branch => "develop"
gem "rdf-spec",       :git => "git://github.com/ruby-rdf/rdf-spec.git", :branch => "develop"
gem "rdf-xsd",        :git => "git://github.com/ruby-rdf/rdf-xsd.git", :branch => "develop"

group :test do
  gem "rdf-microdata",  :git => "git://github.com/ruby-rdf/rdf-microdata.git", :branch => "develop"
  gem 'rdf-turtle',     :git => "git://github.com/ruby-rdf/rdf-turtle.git", :branch => "develop"
  gem 'sparql',         :git => "git://github.com/ruby-rdf/sparql.git", :branch => "develop"
end

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :debug do
  gem "wirble"
  gem "syntax"
  gem "debugger", :platform => "mri_19"
end
