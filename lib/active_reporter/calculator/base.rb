require 'active_reporter/aggregator/base'

module ActiveReporter
  module Calculator
    class Base < ActiveReporter::Aggregator::Base
      def aggregator
        opts[:aggregator] || name
      end

      def parent_aggregator
        opts[:parent_aggregator] || aggregator
      end

      def totals?
        !!opts[:totals]
      end
    end
  end
end
