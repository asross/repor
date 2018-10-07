module Repor
  module Aggregator
    class Min < Repor::Aggregator::Base
      def function
        "MIN(#{expression})"
      end
    end
  end
end
