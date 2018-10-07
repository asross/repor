module Repor
  module Aggregator
    class Max < Repor::Aggregator::Base
      def function
        "MAX(#{expression})"
      end
    end
  end
end
