source "http://rubygems.org"

gemspec

gem "nokogiri", '~> 1.6'
gem 'equivalent-xml', '~> 0.5'

group :development, :test do
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
  gem "byebug", platforms: :mri_21
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
end
