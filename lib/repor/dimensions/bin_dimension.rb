module Repor
  module Dimensions
    class BinDimension < BaseDimension
      def max_bins
        2000
      end

      def min
        @min ||= filter_min || report.records.minimum(expression)
      end

      def max
        @max ||= filter_max || report.records.maximum(expression)
      end

      def data_contains_nil?
        report.records.where("#{expression} IS NULL").exists?
      end

      def filter_min
        filter_values_for(:min).min
      end

      def filter_max
        filter_values_for(:max).max
      end

      def domain
        return 0 if min.nil? || max.nil?
        max - min
      end

      def group_values
        @group_values ||= to_bins(array_param(:bins).presence || autopopulate_bins)
      end

      def filter_values
        @filter_values ||= to_bins(super)
      end

      def filter(relation)
        filter_values.filter(relation, expression)
      end

      def group(relation)
        group_values.group(relation, expression, sql_value_name)
      end

      def validate_params!
        super

        if params.key?(:bin_count)
          unless Repor.numeric?(params[:bin_count])
            invalid_param!(:bin_count, "must be numeric")
          end

          unless params[:bin_count].to_i > 0
            invalid_param!(:bin_count, "must be greater than 0")
          end

          unless params[:bin_count].to_i <= max_bins
            invalid_param!(:bin_count, "must be less than #{max_bins}")
          end
        end

        if array_param(:bins).present?
          unless group_values.all?(&:valid?)
            invalid_param!(:bins, "must be hashes with min/max keys and valid values, or nil")
          end
        end

        if array_param(:only).present?
          unless filter_values.all?(&:valid?)
            invalid_param!(:only, "must be hashes with min/max keys and valid values, or nil")
          end
        end
      end

      def bin_width
        raise NotImplementedError
      end

      def bin_start
        self.min
      end

      private

      def filter_values_for(key)
        filter_values.each_with_object([]) do |filter, values|
          if value = filter.send(key)
            values << value
          end
        end
      end

      def bin_table_class
        self.class.const_get(:BinTable)
      end

      def bin_class
        self.class.const_get(:Bin)
      end

      def to_bins(bins)
        bin_table_class.new(bins.map(&method(:to_bin)))
      end

      def to_bin(bin)
        bin_class.from_hash(bin)
      end

      def sanitize_sql_value(value)
        bin_class.from_sql(value)
      end

      def autopopulate_bins
        # Internal representation -- hashes and nil
        iters = 0
        bins = []
        bin_edge = self.bin_start
        return bins if bin_edge.blank? || max.blank?
        approx_count = (max - bin_edge)/(bin_width)
        if approx_count > max_bins
          invalid_param!(:bin_width, "is too small for the domain; would generate #{approx_count} bins")
        end

        loop do
          break if bin_edge > max
          break if bin_edge == max && filter_values_for(:max).present?
          bin = { min: bin_edge, max: bin_edge + bin_width }
          bins << bin
          bin_edge = bin[:max]
          iters += 1
          raise "too many bins, likely an internal error" if iters > max_bins
        end

        if data_contains_nil?
          if dimension_or_root_param(:nulls_last)
            bins << nil
          else
            bins = [nil] + bins
          end
        end

        bins
      end
    end
  end
end
