module Repor
  module Serializer
    class NestedHash < Base
      def table
        report.hashed_data.collect { |row| row.map { |k,v| [k, (v.respond_to?(:min) ? v.min : v).to_s] }.to_h }.collect do |row|
          report.grouper_names.reverse.inject(row.slice(*report.aggregators.keys)) { |nested_row_data, group| { row[group] => nested_row_data } }
        end.reduce({}, :merge)
      end
    end
  end
end
