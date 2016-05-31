module Repor
  class Report
    delegate :klass, to: :class

    attr_reader :params

    def initialize(params = {})
      @params = params.deep_symbolize_keys.deep_dup
      deep_strip_blanks(@params) unless @params[:strip_blanks] == false
      validate_params!
    end

    def dimensions
      @dimensions ||= build_axes(self.class.dimensions)
    end

    def aggregators
      @aggregators ||= build_axes(self.class.aggregators)
    end

    def aggregator_name
      params.fetch(:aggregator, default_aggregator_name).to_sym
    end

    def aggregator
      @aggregator ||= aggregators[aggregator_name]
    end

    def grouper_names
      names = params.fetch(:groupers, default_grouper_names)
      names = names.is_a?(Hash) ? names.values : Array.wrap(names)
      names.map(&:to_sym)
    end

    def groupers
      @groupers ||= dimensions.values_at(*grouper_names)
    end

    def filters
      @filters ||= dimensions.values.select(&:filtering?)
    end

    def relators
      filters | groupers
    end

    def base_relation
      params.fetch(:relation, klass.all)
    end

    def table_name
      klass.table_name
    end

    def relation
      @relation ||= relators.reduce(base_relation) do |relation, dimension|
        dimension.relate(relation)
      end
    end

    def records
      @records ||= filters.reduce(relation) do |relation, dimension|
        dimension.filter(relation)
      end
    end

    def groups
      @groups ||= groupers.reduce(records) do |relation, dimension|
        dimension.group(relation)
      end
    end

    def raw_data
      @raw_data ||= aggregator.aggregate(groups)
    end

    def group_values
      @group_values ||= all_combinations_of(groupers.map(&:group_values))
    end

    # flat hash of
    # { [x1, x2, x3] => y }
    def flat_data
      @flat_data ||= Hash[group_values.map { |x| [x, raw_data[x]] }]
    end

    # nested array of
    # [{ key: x3, values: [{ key: x2, values: [{ key: x1, value: y }] }] }]
    def nested_data
      @nested_data ||= nest_data
    end

    def data
      nested_data
    end

    class << self
      def dimensions
        @dimensions ||= {}
      end

      def dimension(name, dimension_class, opts = {})
        dimensions[name.to_sym] = { axis_class: dimension_class, opts: opts }
      end

      def aggregators
        @aggregators ||= {}
      end

      def aggregator(name, aggregator_class, opts = {})
        aggregators[name.to_sym] = { axis_class: aggregator_class, opts: opts }
      end

      %w(category number time).each do |type|
        class_eval <<-DIM_HELPERS, __FILE__, __LINE__
          def #{type}_dimension(name, opts = {})
            dimension(name, Dimensions::#{type.classify}Dimension, opts)
          end
        DIM_HELPERS
      end

      %w(count sum avg min max array).each do |type|
        class_eval <<-AGG_HELPERS, __FILE__, __LINE__
          def #{type}_aggregator(name, opts = {})
            aggregator(name, Aggregators::#{type.classify}Aggregator, opts)
          end
        AGG_HELPERS
      end

      def default_class
        self.name.demodulize.sub(/Report$/, '').constantize
      end

      def klass
        @klass ||= default_class
      rescue NameError
        raise NameError, "must specify a class to report on, e.g. `report_on Post`"
      end

      def report_on(class_or_name)
        @klass = class_or_name.to_s.constantize
      end

      # ensure subclasses gain any aggregators or dimensions defined on their parents
      def inherited(subclass)
        instance_values.each do |ivar, ival|
          subclass.instance_variable_set(:"@#{ivar}", ival.dup)
        end
      end

      # autoreporting will automatically define dimensions based on columns
      def autoreport_on(class_or_name)
        report_on class_or_name
        klass.columns.each(&method(:autoreport_column))
        count_aggregator :count if aggregators.blank?
      end

      # can override this method to skip or change certain column declarations
      def autoreport_column(column)
        return if column.name == 'id'
        belongs_to_ref = klass.reflections.find { |_, a| a.foreign_key == column.name }
        if belongs_to_ref
          name, ref = belongs_to_ref
          name_col = (ref.klass.column_names & autoreport_association_name_columns(ref)).first
          if name_col
            name_expr = "#{ref.klass.table_name}.#{name_col}"
            category_dimension name, expression: name_expr, relation: ->(r) { r.joins(name) }
          else
            category_dimension column.name
          end
        elsif column.cast_type.type == :datetime
          time_dimension column.name
        elsif column.cast_type.number?
          number_dimension column.name
        else
          category_dimension column.name
        end
      end

      # override this to change which columns of the association are used to
      # auto-label it
      def autoreport_association_name_columns(reflection)
        %w(name email title)
      end
    end

    private def build_axes(axes)
      axes.map { |name, h| [name, h[:axis_class].new(name, self, h[:opts])] }.to_h
    end

    private def all_combinations_of(values)
      values[0].product(*values[1..-1])
    end

    private def nest_data(groupers=self.groupers, prefix=[])
      head, rest = groupers.last, groupers[0..-2]
      head.group_values.map do |x|
        if rest.any?
          { key: x, values: nest_data(rest, [x]+prefix) }
        else
          { key: x, value: raw_data[([x]+prefix)] }
        end
      end
    end

    private def validate_params!
      incomplete_msg = "You must declare at least one aggregator and one " \
        "dimension to initialize a report. See the README for more details."

      if aggregators.blank?
        raise Repor::InvalidParamsError, "#{self.class} doesn't have any " \
          "aggregators declared! #{incomplete_msg}"
      end

      if dimensions.blank?
        raise Repor::InvalidParamsError, "#{self.class} doesn't have any " \
          "dimensions declared! #{incomplete_msg}"
      end

      unless aggregator.present?
        invalid_param!(:aggregator,
          "#{aggregator_name} is not a valid aggregator (should be in #{aggregators.keys})")
      end

      unless groupers.all?(&:present?)
        invalid_param!(:groupers,
          "one of #{grouper_names} is not a valid dimension (should all be in #{dimensions.keys})")
      end
    end

    private def invalid_param!(param_key, message)
      raise InvalidParamsError, "Invalid value for params[:#{param_key}]: #{message}"
    end

    private def default_aggregator_name
      aggregators.keys.first
    end

    private def default_grouper_names
      [dimensions.keys.first]
    end

    private def strippable_blank?(value)
      case value
      when String, Array, Hash then value.blank?
      else false
      end
    end

    private def deep_strip_blanks(hash, depth = 0)
      raise "very deep hash or, more likely, internal error" if depth > 100
      hash.delete_if do |key, value|
        strippable_blank?(
          case value
          when Hash then deep_strip_blanks(value, depth + 1)
          when Array then value.reject!(&method(:strippable_blank?))
          else value
          end
        )
      end
    end
  end
end
