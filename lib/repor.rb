module Repor
  def self.database_type
    database_adapter_name = ActiveRecord::Base.connection_config[:adapter]
    case database_adapter_name
    when /postgres/ then :postgres
    when /mysql/ then :mysql
    when /sqlite/ then :sqlite
    else
      raise "unsupported database #{database_adapter_name}"
    end
  end

  def self.numeric?(value)
    value.is_a?(Numeric) || value.is_a?(String) && value =~ /\A\d+(?:\.\d+)?\z/
  end
end

require 'repor/invalid_params_error'

require 'repor/aggregator/base'
require 'repor/aggregator/array'
require 'repor/aggregator/average'
require 'repor/aggregator/count'
require 'repor/aggregator/max'
require 'repor/aggregator/min'
require 'repor/aggregator/sum'

require 'repor/calculator/base'
require 'repor/calculator/ratio'

require 'repor/dimension/base'
require 'repor/dimension/bin'
require 'repor/dimension/bin/set'
require 'repor/dimension/bin/table'
require 'repor/dimension/time'
require 'repor/dimension/number'
require 'repor/dimension/category'

require 'repor/serializer/base'
require 'repor/serializer/table'
require 'repor/serializer/csv'
require 'repor/serializer/form_field'
require 'repor/serializer/highcharts'

require 'repor/report'
