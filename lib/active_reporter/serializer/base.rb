require 'active_reporter/inflector'

module ActiveReporter
  module Serializer
    class Base
      attr_reader :report

      def initialize(report)
        @report = report
      end

      # Consider overriding many of these methods to use I18n with keys based
      # on the aggregators or dimension name.

      def human_aggregator_label(aggregators)
        aggregators.keys.collect { |aggregator| aggregator.to_s.humanize }.join(' ')
      end

      def human_dimension_label(dimension)
        dimension.name.to_s.humanize
      end

      def human_null_value_label(dimension)
        "No #{human_dimension_label(dimension)}"
      end

      def human_aggregator_value_label(aggregator, value)
        value
      end

      def human_dimension_value_label(dimension, value)
        return human_null_value_label(dimension) if value.nil?

        case dimension
        when ActiveReporter::Dimension::Category
          human_category_value_label(dimension, value)
        when ActiveReporter::Dimension::Number
          human_number_value_label(dimension, value)
        when ActiveReporter::Dimension::Time
          human_time_value_label(dimension, value)
        else
          value
        end
      end

      def human_category_value_label(dimension, value)
        value
      end

      def human_number_value_label(dimension, value)
        case value.bin_edges
        when :min_and_max
          "[#{value.min.round(2)}, #{value.max.round(2)})"
        when :min
          ">= #{value.min.round(2)}"
        when :max
          "< #{value.max.round(2)}"
        else
          human_null_value_label(dimension)
        end
      end

      def time_formats
        {
          minutes: '%F %k:%M', hours: '%F %k', days: '%F',
          weeks: 'week of %F', months: '%Y-%m', years: '%Y'
        }
      end

      def human_time_value_label(dimension, value)
        case value.bin_edges
        when :min_and_max
          time_formats.each { |step, format| return value.min.strftime(format) if value.max == value.min.advance(step => 1) } || "#{value.min} to #{value.max}"
        when :min
          "after #{value.min}"
        when :max
          "before #{value.max}"
        else
          human_null_value_label(dimension)
        end
      end

      def record_type
        report.table_name.singularize(:_gem_active_reporter).humanize
      end

      def axis_summary
        y = human_aggregator_label(report.aggregators)
        xes = report.groupers.map(&method(:human_dimension_label))
        count = "#{report.records.count} #{record_type.pluralize(report.records.count, :_gem_active_reporter)}"
        "#{y} by #{xes.to_sentence} for #{count}"
      end

      def filter_summary
        report.filters.flat_map do |dimension|
          human_dimension_label(dimension) + " = " + dimension.filter_values.map do |value|
            human_dimension_value_label(dimension, value)
          end.to_sentence(last_word_connector: ', or ')
        end.join('; ')
      end
    end
  end
end
