module Repor
  module Aggregators
    class ArrayAggregator < BaseAggregator
      def aggregation(groups)
        unless Repor.database_type == :postgres
          fail InvalidParamsError, "array agg is only supported in Postgres"
        end

        relate(groups).select("ARRAY_AGG(#{expression}) AS #{sql_value_name}")
      end
    end
  end
end
