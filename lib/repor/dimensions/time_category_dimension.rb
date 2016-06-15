module Repor
  module Dimensions
    class TimeCategoryDimension < CategoryDimension
      def expression
        case time_category
        when :day_of_week
          "DOW(#{super})"
        else
          raise "unsupported time category #{time_category}"
        end
      end

      def time_category
        params.fetch(:time_category, :day_of_week).to_sym
      end
    end
  end
end
