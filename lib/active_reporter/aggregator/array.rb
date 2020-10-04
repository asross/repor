module ActiveReporter
  module Aggregator
    class Array < ActiveReporter::Aggregator::Base
      def aggregate(groups)
        fail InvalidParamsError, 'array agg is only supported in Postgres' unless ActiveReporter.database_type == :postgres
        super
      end

      def function
        "ARRAY_AGG(#{expression})"
      end
    end
  end
end
