module Repor
  module Dimension
    class Bin
      class Table < Array
        def initialize(values)
          super(values.compact)
        end

        def filter(relation, expr)
          relation.where(any_contain(expr))
        end

        def group(relation, expr, value_name)
          name = "#{value_name}_bin_table"

          bin_join = <<-SQL
INNER JOIN (
  #{rows.join(" UNION\n  ")}
) AS #{name} ON (
  CASE
  WHEN #{name}.min IS NULL AND #{name}.max IS NULL THEN (#{expr} IS NULL)
  WHEN #{name}.min IS NULL THEN (#{expr} < #{name}.max)
  WHEN #{name}.max IS NULL THEN (#{expr} >= #{name}.min)
  ELSE ((#{expr} >= #{name}.min) AND (#{expr} < #{name}.max))
  END
)
          SQL

          selection = "#{name}.bin_text AS #{value_name}"
          relation.joins(bin_join).select(selection).group(value_name)
        end

        def rows
          map(&:row_sql)
        end

        def any_contain(expr)
          map { |bin| bin.contains_sql(expr) }.join(' OR ')
        end
      end
    end
  end
end
