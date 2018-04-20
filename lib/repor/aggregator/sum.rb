module Repor
  module Aggregator
    class Sum < Base
      def aggregate(groups)
        relate(groups).select("SUM(#{expression}) AS #{sql_value_name}")
      end
    end
  end
end
