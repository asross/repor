module ActiveReporter
  module Aggregator
    class Sum < ActiveReporter::Aggregator::Base
      def function
        "SUM(#{expression})"
      end

      def default_value
        super || 0
      end
    end
  end
end
