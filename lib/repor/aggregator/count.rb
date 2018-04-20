module Repor
  module Aggregator
    class Count < Base
      def aggregate(groups)
        relate(groups).select("COUNT(DISTINCT #{report.table_name}.id) AS #{sql_value_name}")
      end
    end
  end
end
