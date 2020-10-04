require 'active_reporter/aggregator/base'

module ActiveReporter
  module Tracker
    class Base < ActiveReporter::Aggregator::Base
      def aggregator
        opts[:aggregator] || name
      end

      def prior_aggregator
        opts[:prior_aggregator] || aggregator
      end
    end
  end
end
