module Repor
  module Aggregators
    class BaseAggregator
      attr_reader :name, :report, :opts

      def initialize(name, report, opts={})
        @name = name
        @report = report
        @opts = opts
      end

      # This is the method called by Repor::Report. It should return a hash of
      # array keys (of grouper values) mapped to aggregation values.
      def aggregate(groups)
        query = aggregation(relate(groups))
        result = ActiveRecord::Base.connection.select_all(query)
        result.cast_values.each_with_object(Hash.new(default_y_value)) do |values, h|
          row = result.columns.zip(values).to_h
          h[x_value_of(row)] = y_value_of(row)
        end
      end

      private

      # This is the method any aggregator must implement. It should return a
      # relation with the aggregator value SELECTed as the `sql_value_name`.
      def aggregation(groups)
        raise NotImplementedError
      end

      def sql_value_name
        "_report_aggregator_#{name}"
      end

      def x_value_of(row)
        report.groupers.map { |g| g.extract_sql_value(row) }
      end

      def y_value_of(row)
        row[sql_value_name]
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

      # What value should be returned if there are no results for a certain key?
      # For count, that's clearly 0; for min/max, that may be less clear.
      def default_y_value
        opts.fetch(:default_value, 0)
      end
    end
  end
end
