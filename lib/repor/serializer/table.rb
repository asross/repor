module Repor
  module Serializer
    class Table < Base
      def headers
        report.groupers.map(&method(:human_dimension_label)) + [human_aggregator_label(report.aggregators)]
      end

      def each_row
        return to_enum(__method__) unless block_given?

        report.flat_data.each do |xes, y|
          yield report.groupers.zip(xes).map { |d, v| human_dimension_value_label(d, v) } + [human_aggregator_value_label(report.aggregators, y)]
        end
      end

      def caption
        axis_summary
      end
    end
  end
end
