require 'repor/dimension/base'

module Repor
  module Dimension
    class Category < Base
      def filter(relation)
        values = filter_values
        query = "#{expression} IN (?)"
        query = "#{expression} IS NULL OR #{query}" if values.include?(nil)
        relation.where(query, values.compact)
      end

      def group(relation)
        order relation.select("#{expression} AS #{sql_value_name}").group(sql_value_name)
      end

      def group_values
        return filter_values if filtering?
          
        i = report.groupers.index(self)
        report.raw_data.keys.map { |x| x[i] }.uniq
      end

      def all_values
        relate(report.base_relation).pluck("DISTINCT #{expression}").map(&method(:sanitize_sql_value))
      end
    end
  end
end
