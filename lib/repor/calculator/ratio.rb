module Repor
  module Calculator
    class Ratio < Base
      def initialize(column)
        super
      end

      def evaluate(row, parent_row)
        ((row[field].to_f / parent_row[parent_field].to_f) * 100) unless parent_row[parent_field].to_f == 0
      end
    end
  end
end
