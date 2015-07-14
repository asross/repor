module Repor
  module DimensionBuilders
    class Hist < Binned
      DEFAULT_BIN_COUNT = 5

      def build!
        super

        dimension = self.dimension

        raw_min = :"min_#{dimension}"
        raw_max = :"max_#{dimension}"

        min = :"computed_#{raw_min}"
        max = :"computed_#{raw_max}"
        bstep = :"#{dimension}_bin_size"
        bcount = :"#{dimension}_bin_count"

        m = Module.new do
          define_method :"sanitize_#{dimension}_value" do |f|
            f.is_a?(String) ? f.to_f : f
          end

          define_method :"default_#{bcount}" do
            DEFAULT_BIN_COUNT
          end

          define_method :"default_#{bstep}" do
            range = send(max) - send(min)
            count = params.fetch(bcount, send(:"default_#{bcount}")).to_f
            range / count
          end

          define_method bstep do
            params[bstep].presence || send(:"default_#{bstep}")
          end

          define_method :"new_bin_table_for_#{dimension}" do
            Repor::HistTable.new(send(bstep), send(min), send(max))
          end

          define_method :"filter_params_for_#{dimension}_value" do |value|
            {
              :"min_#{dimension}" => value,
              :"max_#{dimension}" => value + send(bstep)
            }
          end
        end

        report_class.include m
        report_class.hist_dimensions << dimension
      end
    end
  end
end
