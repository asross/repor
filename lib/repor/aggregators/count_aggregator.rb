module Repor
  module Aggregators
    class CountAggregator < BaseAggregator
      def aggregation(groups)
        groups.select("COUNT(DISTINCT #{report.table_name}.id) AS #{sql_value_name}")
      end
    end
  end
end
