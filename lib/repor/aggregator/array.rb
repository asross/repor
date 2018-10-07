module Repor
  module Aggregator
    class Array < Repor::Aggregator::Base
      def aggregate(groups)
        fail InvalidParamsError, 'array agg is only supported in Postgres' unless Repor.database_type == :postgres
        super
      end

      def function
        "ARRAY_AGG(#{expression})"
      end
    end
  end
end
