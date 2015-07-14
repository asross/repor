module Repor
end

module Enumerable
  def uniq_map
    values = Set.new
    each { |element| values << yield(element) }
    values.to_a
  end

  def all_combinations
    self[0].product(*self[1..-1])
  end
end

require 'repor/time_table'
require 'repor/hist_table'

require 'repor/dimension_builders/base'
require 'repor/dimension_builders/enum'
require 'repor/dimension_builders/binned'
require 'repor/dimension_builders/time'
require 'repor/dimension_builders/hist'

require 'repor/report'

require 'repor/exporters/csv'
require 'repor/exporters/highcharts'
