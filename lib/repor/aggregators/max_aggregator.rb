module Repor
  module Aggregators
    class MaxAggregator < BaseAggregator
      def aggregation(groups)
        groups.select("MAX(#{expression}) AS #{sql_value_name}")
      end
    end
  end
end
