module Repor
  module DimensionBuilders
    class Enum < Base
      def value_method_name
        :"#{dimension}_values"
      end

      def build!
        super

        dimension = self.dimension
        expression = self.expression
        value_method_name = self.value_method_name
        group_method_name = self.group_method_name
        filter_method_name = self.filter_method_name
        relation_method_name = self.relation_method_name

        m = Module.new do
          define_method value_method_name do
            Array.wrap(params[value_method_name]).select(&:present?).presence || []
          end

          define_method group_method_name do |r|
            send(relation_method_name, r).group(expression)
          end

          define_method filter_method_name do |r|
            values = send(value_method_name)
            if values.length == 1
              send(relation_method_name, r).where("#{expression} = ?", values.first)
            else
              send(relation_method_name, r).where("#{expression} in (?)", values)
            end
          end

          define_method :"filtering_by_#{dimension}?" do
            send(value_method_name).present?
          end

          define_method :"all_#{dimension}_values" do
            if send(:"filtering_by_#{dimension}?")
              send(value_method_name)
            else
              i = x_axes.index(dimension)
              raw_data.uniq_map { |x, y| Array.wrap(x)[i] }
            end
          end

          define_method :"sanitize_#{dimension}_value" do |value|
            value
          end

          define_method :"filter_params_for_#{dimension}_value" do |value|
            { value_method_name => value }
          end
        end

        report_class.include m
        report_class.enum_dimensions << dimension

        report_class.define_singleton_method :"#{dimension}_filter_params" do
          [value_method_name]
        end
      end
    end
  end
end
