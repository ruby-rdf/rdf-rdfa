source "http://rubygems.org"

gemspec

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :debug do
  gem "wirble"
  gem "syntax"
  gem 'debugger' if defined(RUBY_ENGINE) && RUBY_ENGINE == 'ruby'
end
