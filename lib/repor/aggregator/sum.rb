module Repor
  module Aggregator
    class Sum < Repor::Aggregator::Base
      def function
        "SUM(#{expression})"
      end

      def default_value
        super || 0
      end
    end
  end
end
