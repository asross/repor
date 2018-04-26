module Repor
  module Serializer
    class HashTable < Base
      def table
        fields = (report.grouper_names + report.aggregators.keys)
        titles = report.groupers.map(&method(:human_dimension_label)) + report.aggregators.collect { |k, v| human_aggregator_label({ k => v }) }

        [fields.zip(titles).to_h] + report.hashed_data.collect { |row| row.map { |k,v| [k, (v.try(:min) || v).to_s] }.to_h}
      end
    end
  end
end
