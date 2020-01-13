require 'repor/aggregator/base'

module Repor
  module Calculator
    class Base < Repor::Aggregator::Base
      attr_reader :name, :report, :opts

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
