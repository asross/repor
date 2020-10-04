module ActiveReporter
  module Dimension
    class Base
      attr_reader :name, :report, :opts

      def initialize(name, report, opts={})
        @name = name
        @report = report
        @opts = opts
        validate_params!
      end

      def model
        return @model unless @model.nil?

        @model = opts[:model].to_s.classify.constantize rescue opts[:model]
        @model = report.report_model if @model.nil?

        @model
      end

      def attribute
        opts.fetch(:attribute, name)
      end

      def expression
        @expression ||= opts[:expression] || opts[:_expression] || "#{table_name}.#{column}"
      end

      # Do any joins/selects necessary to filter or group the relation.
      def relate(relation)
        opts.fetch(:relation, ->(r) { r }).call(relation)
      end

      # Filter the relation based on any constraints in the params
      def filter(relation)
        raise NotImplementedError
      end

      # Group the relation by the expression -- ensure this is ordered, too.
      def group(relation)
        raise NotImplementedError
      end

      # Return an ordered array of all values that should appear in `Report#data`
      def group_values
        raise NotImplementedError
      end

      # Given a single (hashified) row of the SQL result, return the Ruby
      # object representing this dimension's value
      def extract_sql_value(row)
        sanitize_sql_value(row[sql_value_name])
      end

      def filter_values
        array_param(:only).uniq
      end

      # Return whether the report should filter by this dimension
      def filtering?
        filter_values.present?
      end

      def grouping?
        report.groupers.include?(self)
      end

      def order_expression
        sql_value_name
      end

      def order(relation)
        relation.order("#{order_expression} #{sort_order} #{null_order}")
      end

      def sort_desc?
        dimension_or_root_param(:sort_desc)
      end

      def sort_order
        sort_desc? ? 'DESC' : 'ASC'
      end

      def nulls_last?
        value = dimension_or_root_param(:nulls_last)
        value = !value if sort_desc?
        value
      end

      def null_order
        return unless ActiveReporter.database_type == :postgres
        nulls_last? ? 'NULLS LAST' : 'NULLS FIRST'
      end

      def params
        report.params.fetch(:dimensions, {})[name].presence || {}
      end

      private

      def validate_params!
        if opts.include?(:expression)
          ActiveSupport::Deprecation.warn("passing an :expression option will be deprecated in version 1.0\n  please use :attribute, and, when required, :model or :table_name")
        end
      end

      def invalid_param!(param_key, message)
        raise InvalidParamsError, "Invalid value for params[:dimensions] [:#{name}][:#{param_key}]: #{message}"
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

      def sql_value_name
        "_active_reporter_dimension_#{name}"
      end

      def sanitize_sql_value(value)
        value
      end

      def dimension_or_root_param(key)
        params.fetch(key, report.params[key])
      end

      def array_param(key)
        return [] unless params.key?(key)
        return [nil] if params[key].nil?
        Array.wrap(params[key])
      end

      def enum?
        false # Hash(model&.defined_enums).include?(attribute.to_s)
      end
    end
  end
end
