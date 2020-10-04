module ActiveReporter
  module Aggregator
    class Max < ActiveReporter::Aggregator::Base
      def function
        "MAX(#{expression})"
      end
    end
  end
end
