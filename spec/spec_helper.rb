# Configure Rails Environment
ENV["RAILS_ENV"] ||= "test"

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'

  add_group 'Report', ['lib/repor.rb', 'lib/repor/report', 'lib/repor/invalid_params_error.rb', 'lib/repor/version.rb']

  add_group 'Aggregators', 'lib/repor/aggregator'
  add_group 'Calculators', 'lib/repor/calculator'
  add_group 'Trackers', 'lib/repor/tracker'

  add_group 'Dimensions', 'lib/repor/dimension'

  add_group 'Serializers', 'lib/repor/serializer'

  add_group 'Tasks', 'lib/repor/tasks'

  add_group "Long files" do |src_file| src_file.lines.count > 100 end
  add_group "Short files" do |src_file| src_file.lines.count < 5 end
end

require File.expand_path("../../spec/dummy/config/environment.rb",  __FILE__)
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../spec/dummy/db/migrate", __FILE__)]
require "rails/test_help"

require 'rspec/rails'
require 'factory_bot_rails'
require 'pry'

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.include FactoryBot::Syntax::Methods
end
