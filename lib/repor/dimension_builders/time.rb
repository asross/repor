module Repor
  module DimensionBuilders
    class Time < Binned
      def build!
        super

        dimension = self.dimension

        raw_min = :"min_#{dimension}"
        raw_max = :"max_#{dimension}"
        min = :"computed_#{raw_min}"
        max = :"computed_#{raw_max}"
        tstep = :"#{dimension}_time_step"

        m = Module.new do
          define_method :"sanitize_#{dimension}_value" do |t|
            t.is_a?(String) ? ::Time.zone.parse(t) : t
          end

          define_method :"default_#{tstep}" do
            case send(max) - send(min)
            when 0..2.weeks then 'day'
            when 2.weeks..8.weeks then 'week'
            when 8.weeks..52.weeks then 'month'
            when 52.weeks..104.weeks then 'quarter'
            else 'year'
            end
          end

          define_method tstep do
            params[tstep].presence || send(:"default_#{tstep}")
          end

          define_method :"new_bin_table_for_#{dimension}" do
            Repor::TimeTable.new(send(tstep), send(min), send(max))
          end

          define_method :"filter_params_for_#{dimension}_value" do |value|
            {
              :"min_#{dimension}" => value,
              :"max_#{dimension}" => value.send(:"end_of_#{send(tstep)}")
            }
          end
        end

        report_class.include m
        report_class.time_dimensions << dimension
      end
    end
  end
end
