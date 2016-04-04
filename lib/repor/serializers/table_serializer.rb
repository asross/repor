module Repor
  module Serializers
    class TableSerializer < BaseSerializer
      def headers
        report.groupers.map(&method(:human_dimension_label)) + [human_aggregator_label(report.aggregator)]
      end

      def each_row
        report.flat_data.each do |xes, y|
          yield report.groupers.zip(xes).map { |d, v| human_dimension_value_label(d, v) } + [human_aggregator_value_label(report.aggregator, y)]
        end
      end

      def caption
        axis_summary
      end
    end
  end
end
