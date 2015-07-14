require 'csv'

module Repor
  module Exporters
    class CSV
      attr_reader :object

      def initialize(report)
        @object = report
      end

      def headers
        object.x_axes + [object.y_axis]
      end

      def each_csv_row
        object.data.each do |key, value|
          yield Array.wrap(key) + [value]
        end
      end

      def csv
        ::CSV.generate do |sheet|
          sheet << headers
          each_csv_row do |row|
            sheet << row
          end
        end
      end
    end
  end
end
