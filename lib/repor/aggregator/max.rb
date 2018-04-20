module Repor
  module Aggregator
    class Max < Base
      def aggregate(groups)
        relate(groups).select("MAX(#{expression}) AS #{sql_value_name}")
      end
    end
  end
end
