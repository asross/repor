module Repor
  module DimensionBuilders
    class Binned < Base
      def build!
        super

        dimension = self.dimension
        min = :"min_#{dimension}"
        max = :"max_#{dimension}"
        expression = self.expression
        group_method_name = self.group_method_name
        filter_method_name = self.filter_method_name
        relation_method_name = self.relation_method_name

        bin_table = :"bin_table_for_#{dimension}"

        m = Module.new do
          define_method(min) { send :"sanitize_#{dimension}_value", params[min].presence }
          define_method(max) { send :"sanitize_#{dimension}_value", params[max].presence }

          define_method(:"computed_#{min}") do
            instance_variable_get(:"@computed_#{min}") || instance_variable_set(:"@computed_#{min}",
              send(min) || send(relation_method_name, records).minimum(expression))
          end

          define_method(:"computed_#{max}") do
            instance_variable_get(:"@computed_#{max}") || instance_variable_set(:"@computed_#{max}",
              send(max) || send(relation_method_name, records).maximum(expression))
          end

          define_method bin_table do
            instance_variable_get(:"@#{bin_table}") || instance_variable_set(:"@#{bin_table}", send(:"new_#{bin_table}"))
          end

          define_method group_method_name do |relation|
            bin_sql = send(bin_table).to_sql

            result = send(relation_method_name, relation)
            result = result.joins <<-SQL
              INNER JOIN (#{bin_sql}) AS #{dimension}_bins
              ON #{expression} >= #{dimension}_bins.min
              AND #{expression} < #{dimension}_bins.max
            SQL
            result.group("#{dimension}_bins.min")
          end

          define_method filter_method_name do |relation|
            # if we're grouping, bin table will implicity filter
            return relation if x_axes.include?(dimension)
            # otherwise, filter by min/max/both/neither.
            result = send(relation_method_name, relation)
            result = result.where("#{expression} >= ?", send(min)) if send(min)
            result = result.where("#{expression} < ?", send(max)) if send(max)
            result
          end

          define_method :"filtering_by_#{dimension}?" do
            send(min) || send(max)
          end

          define_method :"all_#{dimension}_values" do
            send(bin_table).rows.map(&:min)
          end
        end

        report_class.include m

        report_class.define_singleton_method :"#{dimension}_filter_params" do
          [min, max]
        end
      end
    end
  end
end
