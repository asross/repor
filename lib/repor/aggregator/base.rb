module Repor
  module Aggregator
    class Base
      attr_reader :name, :report, :opts

      def initialize(name, report, opts={})
        @name = name
        @report = report
        @opts = opts
      end

      def sql_value_name
        "_report_aggregator_#{name}"
      end

      # What value should be returned if there are no results for a certain key?
      # For count, that's clearly 0; for min/max, that may be less clear.
      def default_value
        opts.fetch(:default_value, 0)
      end

      private

      # This is the method any aggregator must implement. It should return a
      # relation with the aggregator value SELECTed as the `sql_value_name`.
      def aggregate(groups)
        raise NotImplementedError
      end

      def relate(groups)
        relation.call(groups)
      end

      def relation
        opts.fetch(:relation, ->(r) { r })
      end

      def expression
        opts.fetch(:expression, "#{report.table_name}.#{name}")
      end
    end
  end
end
