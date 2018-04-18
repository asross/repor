module Repor
  module Calculator
    class Base
      attr_reader :name, :field, :parent_field, :totals

      def initialize(options)
        @name = options[:name]
        @field = options[:field]
        @parent_field = options[:parent_field]
        @totals = !!options[:totals]
      end
    end
  end
end
