$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "repor/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "repor"
  s.version     = Repor::VERSION
  s.authors     = ["Andrew Ross"]
  s.email       = ["andrew@vermonster.com"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of Repor."
  s.description = "TODO: Description of Repor."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.3"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "factory_girl_rails"
  s.add_development_dependency "database_cleaner"
end
