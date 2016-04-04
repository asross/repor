module Repor
  module Aggregators
    class AvgAggregator < BaseAggregator
      def aggregation(groups)
        groups.select("AVG(#{expression}) AS #{sql_value_name}")
      end
    end
  end
end
