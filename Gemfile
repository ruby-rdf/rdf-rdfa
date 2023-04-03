source "https://rubygems.org"

gemspec

gem "rdf",            github: "ruby-rdf/rdf",      branch: "develop"
gem "rdf-spec",       github: "ruby-rdf/rdf-spec", branch: "develop"
gem "rdf-xsd",        github: "ruby-rdf/rdf-xsd",  branch: "develop"
gem "nokogiri",       '~> 1.13', '>= 1.13.4', platforms: [:mri, :jruby] # Ruby 2.6
gem 'equivalent-xml', '~> 0.6'

group :development, :test do
  gem 'ebnf',               github: "dryruby/ebnf",                 branch: "develop"
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
  gem 'sxp',                github: "dryruby/sxp.rb",               branch: "develop"
end

group :test do
  gem 'simplecov', '~> 0.21',  platforms: :mri
  gem 'simplecov-lcov', '~> 0.8',  platforms: :mri
end

group :debug do
  gem "syntax"
  gem "byebug", platforms: :mri
  gem "rake"
end

platforms :jruby do
  gem 'gson',     '~> 0.6'
end
