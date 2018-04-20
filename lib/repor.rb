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

require 'repor/dimensions/base_dimension'
require 'repor/dimensions/bin_dimension'
require 'repor/dimensions/bin_dimension/bin'
require 'repor/dimensions/bin_dimension/bin_table'
require 'repor/dimensions/time_dimension'
require 'repor/dimensions/number_dimension'
require 'repor/dimensions/category_dimension'

require 'repor/serializer/base'
require 'repor/serializer/table'
require 'repor/serializer/csv'
require 'repor/serializer/form_field'
require 'repor/serializer/highcharts'

require 'repor/report'
