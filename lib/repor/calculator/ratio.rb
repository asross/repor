module Repor
  module Calculator
    class Ratio < Repor::Calculator::Base
      def function
        "SUM(#{expression})"
      end

      def calculate(row, parent_row)
        ((row[aggregator].to_f / parent_row[parent_aggregator].to_f) * 100) unless parent_row[parent_aggregator].to_f == 0
      end
    end
  end
end
