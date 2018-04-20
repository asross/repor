module Repor
  module Aggregator
    class Min < Base
      def aggregate(groups)
        relate(groups).select("MIN(#{expression}) AS #{sql_value_name}")
      end
    end
  end
end
