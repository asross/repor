module Repor
  module Aggregator
    class Sum < Repor::Aggregator::Base
      def function
        "SUM(#{expression})"
      end
    end
  end
end
