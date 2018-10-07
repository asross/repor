module Repor
  module Aggregator
    class Average < Repor::Aggregator::Base
      def function
        "AVG(#{expression})"
      end
    end
  end
end
