module Repor
  module Aggregators
    class MinAggregator < BaseAggregator
      def aggregation(groups)
        relate(groups).select("MIN(#{expression}) AS #{sql_value_name}")
      end
    end
  end
end
