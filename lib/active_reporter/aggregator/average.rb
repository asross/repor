module ActiveReporter
  module Aggregator
    class Average < ActiveReporter::Aggregator::Base
      def function
        "AVG(#{expression})"
      end
    end
  end
end
