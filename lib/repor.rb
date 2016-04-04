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

require 'repor/aggregators/base_aggregator'
require 'repor/aggregators/count_aggregator'
require 'repor/aggregators/avg_aggregator'
require 'repor/aggregators/sum_aggregator'
require 'repor/aggregators/min_aggregator'
require 'repor/aggregators/max_aggregator'
require 'repor/aggregators/array_aggregator'

require 'repor/dimensions/base_dimension'
require 'repor/dimensions/bin_dimension'
require 'repor/dimensions/bin_dimension/bin'
require 'repor/dimensions/bin_dimension/bin_table'
require 'repor/dimensions/time_dimension'
require 'repor/dimensions/number_dimension'
require 'repor/dimensions/category_dimension'

require 'repor/serializers/base_serializer'
require 'repor/serializers/table_serializer'
require 'repor/serializers/csv_serializer'
require 'repor/serializers/form_field_serializer'
require 'repor/serializers/highcharts_serializer'

require 'repor/report'
