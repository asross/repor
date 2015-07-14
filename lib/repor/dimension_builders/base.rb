module Repor
  module DimensionBuilders
    class Base
      attr_reader :report_class, :dimension, :opts

      def initialize(report_class, dimension, opts)
        raise ArgumentError, "duplicate dimension declaration #{dimension}" if report_class.dimensions.include?(dimension.to_sym)
        @report_class = report_class
        @dimension = dimension.to_sym
        @opts = opts
      end

      def expression
        opts.fetch(:expression, "#{report_class.klass.table_name}.#{dimension}")
      end

      def relation_proc
        opts.fetch(:relation, ->(r) { r })
      end

      def build!
        relation_method_name = self.relation_method_name
        relation_proc = self.relation_proc

        m = Module.new do
          define_method(relation_method_name, relation_proc)
        end

        report_class.include m
      end

      def group_method_name
        :"grouped_by_#{dimension}"
      end

      def filter_method_name
        :"filtered_by_#{dimension}"
      end

      def relation_method_name
        :"relation_for_#{dimension}"
      end
    end
  end
end
