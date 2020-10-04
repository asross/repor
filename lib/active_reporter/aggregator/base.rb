module ActiveReporter
  module Aggregator
    class Base
      attr_reader :name, :report, :opts

      def initialize(name, report, opts={})
        @name = name
        @report = report
        @opts = opts
        validate_params!
      end

      def sql_value_name
        "_report_aggregator_#{name}"
      end

      def default_value
        opts.fetch(:default_value, nil)
      end

      def aggregate(groups)
        relate(groups).select("#{function} AS #{sql_value_name}")
      end

      private

      def validate_params!
        if opts.include?(:expression)
          ActiveSupport::Deprecation.warn("passing an :expression option will be deprecated in version 1.0\n  please use :attribute, and, when required, :model or :table_name")
        end
      end

      def relate(groups)
        relation.call(groups)
      end

      def relation
        opts.fetch(:relation, ->(r) { r })
      end

      def model
        opts.fetch(:model, report.report_model)
      end

      def attribute
        opts.fetch(:attribute, name)
      end

      def table_name
        return @table_name unless @table_name.nil?

        @table_name = opts[:table_name]
        @table_name = model.try(:table_name) if @table_name.nil?
        @table_name = model.to_s.constantize.try(:table_name) rescue nil if @table_name.nil?
        @table_name = report.table_name if @table_name.nil?

        @table_name
      end

      def column
        opts.fetch(:column, attribute)
      end

      def expression
        opts.fetch(:expression, "#{table_name}.#{column}")
      end

      def enum?
        false # Hash(model&.defined_enums).include?(attribute.to_s)
      end
    end
  end
end
