module Repor
  module Aggregators
    class BaseAggregator
      attr_reader :name, :report, :opts

      def initialize(name, report, opts={})
        @name = name
        @report = report
        @opts = opts
      end

      # # This is the method called by Repor::Report. It should return a hash of
      # # array keys (of grouper values) mapped to aggregation values.
      # def aggregate(groups, options = {})
      #   options.symbolize_keys!

      #   aggregate_data = if options.include?(:raw_data)
      #     options[:raw_data]
      #   else
      #     query = aggregation(groups)
      #     results = ActiveRecord::Base.connection.select_all(query)
      #     columns = results.columns

      #     results.cast_values.each_with_object(Hash.new(default_value)) do |values, h|
      #       row = columns.zip(values).to_h
      #       h[x_value_of(row)] = y_value_of(row)
      #     end
      #   end

      #   if options.include?(:calculations)
      #     parent_data = options[:parent_report].data
      #     parent_groupers = options[:parent_groupers]
      #     parent_totals = parent_data.totals

      #     aggregate_data.each do |row|
      #       parent_row = parent_data.dig(*parent_groupers)

      #       options[:calculations].each do |calculator|
      #         row[calculator.name] = if calculator[:totals]
      #           calculator.evaluate(row, parent_totals)
      #         else
      #           calculator.evaluate(row, parent_row) unless parent_row.nil?
      #         end
      #       end
      #     end
      #   end

      #   aggregate_data
      # end

      # def total(options = {})
      #   options.symbolize_keys!

      #   totals_data = if options.include?(:totals_data)
      #     options[:totals_data] || {}
      #   else
      #     report.aggregators.collect do |name, aggregator|
      #       aggregator_report = report_class.new(report.instance_variable_get(:@params).except(:dimensions).merge({groupers: :totals}))
      #       aggregator_report.instance_variable_set(:@aggregators, aggregator_report.send(:build_axes, report_class.aggregators.slice(name)))
      #       aggregator_report.instance_variable_set(:@aggregator, aggregator)

      #       [name, aggregator_report.raw_data.values.first]
      #     end.to_h
      #   end

      #   if options.include?(:calculations)
      #     parent_data = options[:parent_report].totals
      #     parent_groupers = options[:parent_groupers]
      #     parent_totals = parent_data.totals

      #     totals_data.each do |row|
      #       parent_row = parent_data.dig(*parent_groupers)

      #       options[:calculations].each do |calculator|
      #         row[calculator.name] = if calculator[:totals]
      #           calculator.evaluate(row, parent_totals)
      #         else
      #           calculator.evaluate(row, parent_row) unless parent_row.nil?
      #         end
      #       end
      #     end
      #   end

      #   totals_data
      # end

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
      def aggregation(groups)
        raise NotImplementedError
      end

      # def x_value_of(row)
      #   report.groupers.map { |g| g.extract_sql_value(row) }
      # end

      # def y_value_of(row)
      #   row[sql_value_name]
      # end

      def relate(groups)
        relation.call(groups)
      end

      def relation
        opts.fetch(:relation, ->(r) { r })
      end

      def expression
        opts.fetch(:expression, "#{report.table_name}.#{name}")
      end

      # def report_class
      #   report.class
      # end
    end
  end
end
