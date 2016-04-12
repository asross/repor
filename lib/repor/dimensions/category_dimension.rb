module Repor
  module Dimensions
    class CategoryDimension < BaseDimension
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
        if filtering?
          filter_values
        else
          i = report.groupers.index(self)
          report.raw_data.map { |x, _y| x[i] }.uniq
        end
      end

      def all_values
        values = relate(report.base_relation).pluck("DISTINCT #{expression}")
        values.map(&method(:sanitize))
      end
    end
  end
end
