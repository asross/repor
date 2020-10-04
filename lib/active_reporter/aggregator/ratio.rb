module ActiveReporter
  module Aggregator
    class Ratio < ActiveReporter::Aggregator::Base
      attr_reader :numerator, :denominator

      def function
        "(#{numerator}/NULLIF(#{denominator},0))"
      end

      private

      def numerator
        raise "Ratio aggregator must specify a numerator column" unless opts.include?(:numerator)
        @numerator = report.aggregators[opts[:numerator].to_sym].try(:function) || "#{report.table_name}.#{opts[:numerator]}"
      end

      def denominator
        raise "Ratio aggregator must specify a denominator column" unless opts.include?(:denominator)
        @denominator = report.aggregators[opts[:denominator].to_sym].try(:function) || "#{report.table_name}.#{opts[:denominator]}"
      end
    end
  end
end
