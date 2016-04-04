module Repor
  module Aggregators
    class SumAggregator < BaseAggregator
      def aggregation(groups)
        groups.select("SUM(#{expression}) AS #{sql_value_name}")
      end
    end
  end
end
