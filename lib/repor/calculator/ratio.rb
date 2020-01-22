module Repor
  module Calculator
    class Ratio < Repor::Calculator::Base
      def calculate(row, parent_row)
        ((row[aggregator].to_f / parent_row[parent_aggregator].to_f) * 100) unless parent_row[parent_aggregator].to_f.zero?
      end
    end
  end
end
