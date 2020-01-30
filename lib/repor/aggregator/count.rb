module Repor
  module Aggregator
    class Count < Repor::Aggregator::Base
      def function
        "COUNT(DISTINCT #{report.table_name}.id)"
      end

      def default_value
        super || 0
      end

      private

      def column
        super || 'id'
      end
    end
  end
end
