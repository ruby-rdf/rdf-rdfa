source "http://rubygems.org"

gemspec

gem "rdf",            github: "ruby-rdf/rdf",      branch: "develop"
gem "rdf-spec",       github: "ruby-rdf/rdf-spec", branch: "develop"
gem "rdf-xsd",        github: "ruby-rdf/rdf-xsd",  branch: "develop"
gem "nokogiri", '~> 1.6'
gem 'equivalent-xml', '~> 0.5'

group :development, :test do
  gem 'ebnf',               github: "gkellogg/ebnf",                branch: "develop"
  gem 'json-ld',            github: "ruby-rdf/json-ld",             branch: "develop"
  gem 'rdf-aggregate-repo', github: "ruby-rdf/rdf-aggregate-repo",  branch: "develop"
  gem 'rdf-isomorphic',     github: "ruby-rdf/rdf-isomorphic",      branch: "develop"
  gem "rdf-microdata",      github: "ruby-rdf/rdf-microdata",       branch: "develop"
  gem 'rdf-rdfxml',         github: "ruby-rdf/rdf-rdfxml",          branch: "develop"
  gem 'rdf-tabular',        github: "ruby-rdf/rdf-tabular",         branch: "develop"
  gem 'rdf-turtle',         github: "ruby-rdf/rdf-turtle",          branch: "develop"
  gem 'rdf-vocab',          github: "ruby-rdf/rdf-vocab",           branch: "develop"
  gem 'sparql',             github: "ruby-rdf/sparql",              branch: "develop"
  gem 'sparql-client',      github: "ruby-rdf/sparql-client",       branch: "develop"
  gem 'sxp',                github: "gkellogg/sxp-ruby",            branch: "develop"
end

group :test do
  gem 'simplecov',      require: false
  gem 'coveralls',      require: false
  gem 'psych',          platforms: [:mri, :rbx]
end

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :debug do
  gem "wirble"
  gem "syntax"
  gem "byebug", platforms: :mri
  gem "ruby-debug", platforms: :jruby
  gem "rake"
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
end

platforms :jruby do
  gem 'gson',     '~> 0.6'
end
