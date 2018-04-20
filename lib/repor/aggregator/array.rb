module Repor
  module Aggregator
    class Array < Base
      def aggregate(groups)
        fail InvalidParamsError, 'array agg is only supported in Postgres' unless Repor.database_type == :postgres

        relate(groups).select("ARRAY_AGG(#{expression}) AS #{sql_value_name}")
      end
    end
  end
end
