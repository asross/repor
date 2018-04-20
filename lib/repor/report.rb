module Repor
  class Report
    delegate :klass, to: :class

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

      %w(count sum average min max array).each do |type|
        class_eval <<-AGG_HELPERS, __FILE__, __LINE__
          def #{type}_aggregator(name, opts = {})
            aggregator(name, Aggregator::#{type.classify}, opts)
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
        elsif %i[datetime timestamp time date].include? column.type
          time_dimension column.name
        elsif %i[integer float decimal].include? column.type
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

    attr_reader :params

    def initialize(params = {})
      @params = params.deep_symbolize_keys.deep_dup
      deep_strip_blanks(@params) unless @params[:strip_blanks] == false
      @params[:parent_groupers] ||= @params[:groupers] if @params.include?(:calculations)
      validate_params!
    end

    def dimensions
      @dimensions ||= build_axes(self.class.dimensions)
    end

    def aggregators
      @aggregators ||= build_axes(self.class.aggregators.slice(*Array(params.fetch(:aggregators, self.class.aggregators.keys)).collect(&:to_sym)))
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

    def aggregation
      return @aggregation unless @aggregation.nil?

      options = @params.slice(:raw_data, :parent_report, :parent_groupers, :calculations).compact

      @aggregation = if options.include?(:raw_data)
        options[:raw_data]
      else
        results = aggregators.values.reduce(groups) { |relation, aggregator| relation.merge(aggregator.aggregate(base_relation)) }

        results.each_with_object({}) do |obj, results_hash|
          aggregators.each do |name, aggregator|
            results_hash[groupers.map { |g| g.extract_sql_value(obj) }.push(name.to_s)] = obj.attributes[aggregator.sql_value_name] || aggregator.default_value
          end
        end
      end

      # if options.include?(:calculations)
      #   parent_data = options[:parent_report].data
      #   parent_groupers = options[:parent_groupers]
      #   parent_totals = parent_data.totals

      #   @aggregation.each do |row|
      #     parent_row = parent_data.dig(*parent_groupers)

      #     options[:calculations].each do |calculator|
      #       row[calculator.name] = if calculator[:totals]
      #         calculator.evaluate(row, parent_totals)
      #       else
      #         calculator.evaluate(row, parent_row) unless parent_row.nil?
      #       end
      #     end
      #   end
      # end

      @aggregation
    end

    def total
      return @total unless @total.nil?

      options = @params.slice(:total_data, :parent_report, :parent_groupers, :calculations).compact

      @total = if options.include?(:total_data)
        options[:total_data]
      else
        total_report = self.class.new(@params.except(:dimensions).merge({groupers: :totals}))
        total_report.aggregation
      end

      # if options.include?(:calculations)
      #   parent_data = options[:parent_report].totals
      #   parent_groupers = options[:parent_groupers]
      #   parent_totals = parent_data.totals

      #   @total.each do |row|
      #     parent_row = parent_data.dig(*parent_groupers)

      #     options[:calculations].each do |calculator|
      #       row[calculator.name] = if calculator[:totals]
      #         calculator.evaluate(row, parent_totals)
      #       else
      #         calculator.evaluate(row, parent_row) unless parent_row.nil?
      #       end
      #     end
      #   end
      # end

      @total
    end

    def calculations
      @calculations ||= Array(params[:calculations]).collect do |calculation, options|
        calculator_class = "Calculator::#{options[:calculator]}".safe_constantize
        calculator_class.new(options.merge({name: calculation})) unless calculator_class.nil?
      end.compact
    end

    def raw_data
      @raw_data ||= case
      when @params.include?(:raw_data) && @params.exclude?(:calculations)
        @params[:raw_data]
      else
        aggregation
      end
    end

    def group_values
      @group_values ||= all_combinations_of(groupers.map(&:group_values))
    end

    # flat hash of
    # { [x1, x2, x3] => y }
    def flat_data
      @flat_data ||= Hash[
        group_values.map do |group|
          aggregators.map do |name, aggregator|
            group_aggregator = group + [name.to_s]
            [group_aggregator, (raw_data[group_aggregator] || aggregator.default_value)]
          end
        end.flatten(1).to_h
      ]
    end

    # nested array of
    # [{ key: x3, values: [{ key: x2, values: [{ key: x1, value: y }] }] }]
    def nested_data
      @nested_data ||= nest_data
    end
    alias_method :data, :nested_data

    def total_data
      @total_data ||= case
      when @params.include?(:raw_data) && @params.exclude?(:calculations)
        @params[:total_data] || {}
      else
        total
      end
    end
    alias_method :totals, :total_data

    private

    def build_axes(axes)
      axes.map { |name, h| [name, h[:axis_class].new(name, self, h[:opts])] }.to_h
    end

    def all_combinations_of(values)
      values[0].product(*values[1..-1])
    end

    def nest_data(groupers=self.groupers, prefix=[])
      groupers = groupers.dup
      group = groupers.pop

      group.group_values.map do |x|
        if groupers.any?
          { key: x, values: nest_data(groupers, [x]+prefix) }
        else
          { key: x, values: aggregators.collect { |name, aggregator| { key: name.to_s, value: ( raw_data[([x]+prefix+[name.to_s])] || aggregator.default_value ) } } }
        end
      end
    end

    def validate_params!
      incomplete_msg = "You must declare at least one aggregator and one dimension to initialize a report. See the README for more details."
      raise Repor::InvalidParamsError, "#{self.class.name} doesn't have any aggregators declared! #{incomplete_msg}" if aggregators.empty?
      raise Repor::InvalidParamsError, "#{self.class.name} doesn't have any dimensions declared! #{incomplete_msg}" if dimensions.empty?
      raise Repor::InvalidParamsError, 'parent_report must be included in order to process calculations' if @params.include?(:calculations) && @params.exclude?(:parent_report)

      (aggregators.keys - self.class.aggregators.keys).each do |aggregator_name|
        invalid_param!(:aggregator, "#{aggregator_name} is not a valid aggregator (should be in #{aggregators.keys})")
      end

      invalid_param!(:groupers, "one of #{grouper_names} is not a valid dimension (should all be in #{dimensions.keys})") unless groupers.all?(&:present?)
      invalid_param!(:parent_report, 'must be an instance of Repor::Report') unless @params.exclude?(:parent_report) || @params[:parent_report].kind_of?(Repor::Report)
    end

    def invalid_param!(param_key, message)
      raise InvalidParamsError, "Invalid value for params[:#{param_key}]: #{message}"
    end

    def default_grouper_names
      [dimensions.keys.first]
    end

    def strippable_blank?(value)
      case value
      when String, Array, Hash then value.blank?
      else false
      end
    end

    def deep_strip_blanks(hash, depth = 0)
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
