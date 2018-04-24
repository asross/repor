module Repor
  module Calculator
    class Base
      attr_reader :name, :report, :opts, :field, :parent_field, :totals, :default_value

      def initialize(name, report, opts={})
        @name = name
        @report = report
        @opts = opts

        @field = opts[:field]
        @parent_field = opts[:parent_field] || @field
        @totals = !!opts[:totals]
        @default_value = opts[:default_value]
      end

      def totals?
        totals
      end
    end
  end
end
