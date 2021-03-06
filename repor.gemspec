$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "repor/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "repor"
  s.version     = Repor::VERSION
  s.authors     = ["Andrew Ross"]
  s.email       = ["andrewslavinross@gmail.com"]
  s.homepage    = "http://github.com/asross/repor"
  s.summary     = "Rails data aggregation framework"
  s.description = "Flexible but opinionated framework for defining and running reports on Rails models backed by SQL databases."
  s.license     = "MIT"

  s.files = Dir["lib/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", "~> 4"

  s.add_development_dependency "pg", "~> 0.18"
  s.add_development_dependency "sqlite3", "~> 1.3"
  s.add_development_dependency "mysql2", "~> 0.3"
  s.add_development_dependency "rspec-rails", "~> 3"
  s.add_development_dependency "factory_girl_rails", "~> 4.5"
  s.add_development_dependency "database_cleaner", "~> 1.4"
  s.add_development_dependency "pry", "~> 0.10"
  s.add_development_dependency "faker", "~> 1.6"
end
