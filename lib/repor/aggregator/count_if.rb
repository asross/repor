module Repor
  module Aggregator
    class CountIf < Repor::Aggregator::Count
      def function
        "COUNT(#{expression} IN (#{values.map(&:to_s).join(',')}) OR NULL)"
      end

      def default_value
        super || 0
      end

      private

      def values
        Array(opts[:values] || opts[:value] || true).compact
      end

      def column
        super || 'id'
      end
    end
  end
end
