module Repor
  module Aggregator
    class Count < Repor::Aggregator::Base
      def function
        "COUNT(DISTINCT #{report.table_name}.id)"
      end
    end
  end
end
