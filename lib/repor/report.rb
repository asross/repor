module Repor
  class Report
    delegate :klass, :dimensions, :aggregators, to: :class

    attr_reader :params

    def initialize(params = {})
      @params = params.with_indifferent_access
      raise ArgumentError, 'must pass a valid y axis' unless aggregators.include?(y_axis)
      raise ArgumentError, 'must pass valid x axes' unless x_axes.all? { |x_axis| dimensions.include?(x_axis) }
    end

    def default_y_axis
      aggregators.first
    end

    def y_axis
      safe_fetch(:y_axis, default_y_axis)
    end

    def default_x_axis
      dimensions.first
    end

    def x_axis
      safe_fetch(:x_axis, default_x_axis)
    end

    def x_axis2
      safe_fetch(:x_axis2)
    end

    def x_axes
      safe_fetch_array(:x_axes, [x_axis, x_axis2].compact)
    end

    def filters
      dimensions.select { |d| send(:"filtering_by_#{d}?") }
    end

    def relation
      params.fetch(:relation, klass.all)
    end

    def records
      @records ||= filters.reduce(relation) do |relation, filter|
        send(:"filtered_by_#{filter}", relation)
      end
    end

    def groups
      @groups ||= x_axes.reduce(records) do |relation, grouper|
        send(:"grouped_by_#{grouper}", relation)
      end
    end

    def raw_data
      @raw_data ||= send(:"aggregated_by_#{y_axis}", groups)
    end

    def x_values
      @x_values ||= x_axes.map { |axis| send(:"all_#{axis}_values") }.all_combinations
    end

    def data
      @data ||= begin
        data = {}
        x_values.each { |x| data[x] = 0 }
        raw_data.each { |x, y| data[sanitize(x)] = y }
        data
      end
    end

    class << self
      def report_on(class_name)
        @class_name = class_name.to_s
      end

      def class_name
        @class_name ||= name.demodulize.sub(/Report$/, '')
      end

      def klass
        class_name.constantize
      end

      def aggregators
        @aggregators ||= []
      end

      def aggregator(name, aggregation_proc, options = {})
        raise ArgumentError, "duplicate aggregator declaration #{name}" if aggregators.include?(name.to_sym)
        aggregators << name.to_sym
        define_method :"aggregated_by_#{name}", aggregation_proc
      end

      def dimension_types
        %w(enum time hist)
      end

      def dimensions
        dimension_types.reduce([]) { |memo, type| memo += send(:"#{type}_dimensions") }
      end

      def inherited(subclass)
        instance_values.each { |ivar, ival| subclass.instance_variable_set(:"@#{ivar}", ival) }
      end

      def filter_params
        dimensions.flat_map { |d| send(:"#{d}_filter_params") }
      end
    end

    dimension_types.each do |dimension_type|
      instance_eval <<-RUBY
        def #{dimension_type}_dimension(dimension, opts = {})
          Repor::DimensionBuilders::#{dimension_type.classify}.new(self, dimension, opts).build!
        end

        def #{dimension_type}_dimensions
          @#{dimension_type}_dimensions ||= []
        end
      RUBY
    end

    def filter_params
      self.class.filter_params.each_with_object({}) do |param, h|
        if value = send(param).presence
          h[param] = value
        end
      end
    end

    def safe_fetch(key, default=nil)
      params[key].presence.try(:to_sym) || default
    end

    def safe_fetch_array(key, default=nil)
      Array.wrap(params[key]).select(&:present?).map(&:to_sym).presence || default
    end

    def sanitize(x_values)
      x_axes.zip(Array.wrap(x_values)).map do |axis, value|
        send(:"sanitize_#{axis}_value", value)
      end
    end
  end
end
