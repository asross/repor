require 'repor/aggregator/base'

module Repor
  module Tracker
    class Base < Repor::Aggregator::Base
      def aggregator
        opts[:aggregator] || name
      end

      def prior_aggregator
        opts[:prior_aggregator] || aggregator
      end
    end
  end
end
