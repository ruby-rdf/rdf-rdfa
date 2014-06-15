source "http://rubygems.org"

gemspec

gem "rdf",            git: "git://github.com/ruby-rdf/rdf.git", branch: "develop"
gem "rdf-spec",       git: "git://github.com/ruby-rdf/rdf-spec.git", branch: "develop"
gem "rdf-xsd",        git: "git://github.com/ruby-rdf/rdf-xsd.git", branch: "develop"
gem "nokogiri" unless ENV["WITH_NOKOGIRI"] == "false"

group :test do
  gem 'rdf-aggregate-repo', git: "git://github.com/ruby-rdf/rdf-aggregate-repo.git", branch: "develop"
  gem "rdf-microdata",  git: "git://github.com/ruby-rdf/rdf-microdata.git", branch: "develop" unless ENV["WITH_NOKOGIRI"] == "false"
  gem 'rdf-turtle',     git: "git://github.com/ruby-rdf/rdf-turtle.git", branch: "develop"
  gem 'rdf-isomorphic', git: "git://github.com/ruby-rdf/rdf-isomorphic.git", branch: "develop"
  gem 'rdf-rdfxml',     git: "git://github.com/ruby-rdf/rdf-rdfxml.git", branch: "develop"
  gem 'json-ld',        git: "git://github.com/ruby-rdf/json-ld.git", branch: "develop"
  gem 'sparql',         git: "git://github.com/ruby-rdf/sparql.git", branch: "develop"
  gem 'sparql-client',  git: "git://github.com/ruby-rdf/sparql-client.git", branch: "develop"
end

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :debug do
  gem "wirble"
  gem "syntax"
  gem "debugger", platforms: :mri_19
  gem "byebug", platforms: [:mri_20, :mri_21]
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
end
