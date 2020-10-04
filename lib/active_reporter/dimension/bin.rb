require 'active_reporter/dimension/base'

module ActiveReporter
  module Dimension
    class Bin < Base
      MAX_BINS = 2_000

      def max_bins
        self.class::MAX_BINS
      end

      def min
        @min ||= filter_min || report.records.minimum(expression)
      end
      alias bin_start min

      def max
        @max ||= filter_max || report.records.maximum(expression)
      end

      def filter_min
        filter_values_for(:min).min
      end

      def filter_max
        filter_values_for(:max).max
      end

      def domain
        min.nil? || max.nil? ? 0 : (max - min)
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
          invalid_param!(:bin_count, "must be numeric") unless ActiveReporter.numeric?(params[:bin_count])
          invalid_param!(:bin_count, "must be greater than 0") unless params[:bin_count].to_i > 0
          invalid_param!(:bin_count, "must be less than #{max_bins}") unless params[:bin_count].to_i <= max_bins
        end

        if array_param(:bins).present?
          invalid_param!(:bins, "must be hashes with min/max keys and valid values, or nil") unless group_values.all?(&:valid?)
        end

        if array_param(:only).present?
          invalid_param!(:only, "must be hashes with min/max keys and valid values, or nil") unless filter_values.all?(&:valid?)
        end
      end

      private

      def filter_values_for(key)
        filter_values.map { |filter_value| filter_value.send(key) }.compact
      end

      def table
        self.class.const_get(:Table)
      end

      def set
        self.class.const_get(:Set)
      end

      def to_bins(bins)
        table.new(bins.map(&method(:to_bin)))
      end

      def to_bin(bin)
        set.from_hash(bin)
      end

      def sanitize_sql_value(value)
        set.from_sql(value)
      end

      def data_contains_nil?
        report.records.where("#{expression} IS NULL").exists?
      end

      def autopopulate_bins
        return [] if bin_start.blank? || max.blank?

        bin_max = filter_values_for(:max).present? ? (max - bin_width) : max
        
        bin_count = (bin_max - bin_start)/(bin_width)
        invalid_param!(:bin_width, "is too small for the domain; would generate #{bin_count} bins") if bin_count > max_bins

        bin_edge = bin_start
        bins = []

        loop do
          break if bin_edge > bin_max

          bin = { min: bin_edge, max: bin_edge + bin_width }
          bins << bin
          bin_edge = bin[:max]
        end

        bins.reverse! if sort_desc?
        ( nulls_last? ? bins.push(nil) : bins.unshift(nil) ) if data_contains_nil?

        bins
      end
    end
  end
end
