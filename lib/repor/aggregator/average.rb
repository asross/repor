module Repor
  module Aggregator
    class Average < Base
      def aggregate(groups)
        relate(groups).select("AVG(#{expression}) AS #{sql_value_name}")
      end
    end
  end
end
