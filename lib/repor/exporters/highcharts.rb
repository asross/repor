module Repor
  module Exporters
    class Highcharts
      attr_reader :object, :series, :categories

      delegate :y_axis, :x_axis, :x_axis2, to: :object

      def initialize(report)
        if report.x_axes.count > 2
          raise ArgumentError, "can't generate chart for more than 2 x-axes" 
        end

        @object = report

        series = Hash.new { |h, k| h[k] = { name: k.to_s, data: [] } }
        categories = Set.new
        object.data.each do |xes, y|
          x1, x2 = xes
          categories << x1
          series[x2 || y_axis_label][:data] << point_options(xes, y)
        end

        @series = series.values
        @categories = categories.entries
      end

      # override this to add specific formatting; e.g. different colors
      def point_options(xes, y)
        { y: y, filters: filters_for(xes) }
      end

      # this provides the parameters necessary to filter the report down to a specific point's data
      def filters_for(xes)
        object.x_axes.zip(xes).each_with_object({}) do |(axis, value), h|
          h.merge!(object.send(:"filter_params_for_#{axis}_value", value))
        end
      end

      def highcharts_options
        {
          chart: {
            type: 'column'
          },
          title: {
            text: title
          },
          yAxis: {
            title: { text: y_axis_label }
          },
          xAxis: {
            categories: categories,
            title: { text: x_axis_label }
          },
          plotOptions: {
            column: {
              stacking: 'normal'
            },
            series: {
              events: {}
            }
          },
          tooltip: {
            headerFormat: "<span>{point.key}#{"<br/>{series.name}" if x_axis2}</span><br/>",
            pointFormat: "<span style='color:{point.color}'>\u25CF</span> #{y_axis_label}: <b>{point.y}</b><br/>"
          },
          series: series
        }
      end

      def title
        "#{y_axis_label} by #{x_axis_label}"
      end

      def y_axis_label
        format_axis(y_axis)
      end

      def x_axis_label
        object.x_axes.map(&method(:format_axis)).join(' and ')
      end

      def format_axis(axis)
        axis.to_s.humanize
      end
    end
  end
end
