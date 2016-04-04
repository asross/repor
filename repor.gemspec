$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "repor/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "repor"
  s.version     = Repor::VERSION
  s.authors     = ["Andrew Ross"]
  s.email       = ["andrew@vermonster.com"]
  s.homepage    = "http://github.com/asross/repor"
  s.summary     = "Rails data aggregation framework"
  s.description = "Flexible but opinionated framework for defining and running reports on Rails models backed by SQL databases."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.3"

  s.add_development_dependency "pg"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "mysql2", "~> 0.3.13"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "factory_girl_rails"
  s.add_development_dependency "database_cleaner"
  s.add_development_dependency "pry"
  s.add_development_dependency "faker"
end
