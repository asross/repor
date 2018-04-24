module Repor
  class Report
    delegate :klass, to: :class

    attr_reader :params, :parent_report, :parent_groupers

    class << self
      def dimensions
        @dimensions ||= { totals: { axis_class: Dimension::Category, opts: { expression: "'totals'" } } }
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

      def calculators
        @calculators ||= {}
      end

      def calculator(name, calculator_class, opts = {})
        calculators[name.to_sym] = { axis_class: calculator_class, opts: opts }
      end

      %w(category number time).each do |type|
        class_eval <<-DIM_HELPERS, __FILE__, __LINE__
          def #{type}_dimension(name, opts = {})
            dimension(name, Dimension::#{type.classify}, opts)
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

      %w(ratio).each do |type|
        class_eval <<-AGG_HELPERS, __FILE__, __LINE__
          def #{type}_calculator(name, opts = {})
            calculator(name, Calculator::#{type.classify}, opts)
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

    def initialize(params = {})
      @params = params.deep_symbolize_keys.deep_dup.compact
      deep_strip_blanks(@params) unless @params[:strip_blanks] == false

      @parent_report = @params.delete(:parent_report)
      @parent_groupers = @params.delete(:parent_groupers) || ( grouper_names & Array(parent_report&.grouper_names) )

      @raw_data = @params.delete(:raw_data)
      @total_report = @params.delete(:total_report)
      @total_data = @params.delete(:total_data) || @total_report&.data

      validate_params!

      if @params.include?(:calculators)
        aggregate if @raw_data.present?
        total if @total_data.present?
      end
    end

    def dimensions
      @dimensions ||= build_axes(self.class.dimensions)
    end

    def aggregators
      @aggregators ||= build_axes(self.class.aggregators.slice(*Array(params.fetch(:aggregators, self.class.aggregators.keys)).collect(&:to_sym)))
    end

    def grouper_names
      names = params.fetch(:groupers, [dimensions.except(:totals).keys.first])
      names = names.is_a?(Hash) ? names.values : Array.wrap(names).compact
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

    def calculators
      @calculators ||= build_axes(self.class.calculators.slice(*Array(params[:calculators]).collect(&:to_sym)))
    end

    def raw_data
      @raw_data ||= aggregate
    end

    def group_values
      @group_values ||= all_combinations_of(groupers.map(&:group_values))
    end

    # flat hash of
    # { [x1, x2, x3] => y }
    def flat_data
      @flat_data ||= flatten_data
    end

    # nested array of
    # [{ key: x3, values: [{ key: x2, values: [{ key: x1, value: y }] }] }]
    def nested_data
      @nested_data ||= nest_data
    end
    alias_method :data, :nested_data

    def total_report
      @total_report ||= self.class.new(@params.except(:calculators).merge({groupers: :totals})) unless @total_data.present?
    end

    def total_data
      @total_data ||= total
    end
    alias_method :totals, :total_data

    private

    def build_axes(axes)
      axes.map { |name, h| [name, h[:axis_class].new(name, self, h[:opts])] }.to_h
    end

    def all_combinations_of(values)
      values[0].product(*values[1..-1])
    end

    def aggregate
      aggregators.values.reduce(groups) do |relation, aggregator|
        relation.merge(aggregator.aggregate(base_relation))
      end.each_with_object({}) do |obj, results_hash|
        aggregators.each do |name, aggregator|
          results_hash[groupers.map { |g| g.extract_sql_value(obj) }.push(name.to_s)] = obj.attributes[aggregator.sql_value_name] || aggregator.default_value
        end

        next if parent_report.nil?
        row_data = {}
        row_data.merge!(dimensions.keys.zip(dimensions.values.collect { |dimension| obj.attributes[dimension.send(:sql_value_name)] }).to_h)
        row_data.merge!(aggregators.keys.zip(aggregators.values.collect { |aggregator| obj.attributes[aggregator.sql_value_name] || aggregator.default_value }).to_h)
        row_data.symbolize_keys!

        calculators.each do |name, calculator|
          calc_report = calculator.totals? ? parent_report.total_report : parent_report

          parent_row, parent_value = match_parent_row_for_calculator(row_data, calc_report, calculator)
          results_hash[groupers.map { |g| g.extract_sql_value(obj) }.push(name.to_s)] = calculator.evaluate(row_data, hash_raw_row(parent_row, parent_value, calc_report.grouper_names)) unless parent_row.nil?
        end
      end
    end

    def hash_raw_row(row, value, grouper_names)
      row_hash = grouper_names.dup.push(:dimension, :value).zip(row.dup.push(value)).to_h
      row_hash[row_hash.delete(:dimension)] = row_hash.delete(:value)
      row_hash.symbolize_keys!
      row_hash
    end

    def match_parent_row_for_calculator(row_data, parent_report, calculator)
      parent_report.flat_data.detect do |parent_row, parent_value|
        parent_row_data = hash_raw_row(parent_row, parent_value, parent_report.grouper_names)
        parent_groupers.all? { |g| row_data[g] == parent_row_data[g] } && parent_row_data.include?(calculator.field.to_sym)
      end
    end

    def flatten_data
      group_values.map do |group|
        aggregators.map do |name, aggregator|
          aggregator_group = group + [name.to_s]
          [aggregator_group, (raw_data[aggregator_group] || aggregator.default_value)]
        end
      end.flatten(1).to_h
    end

    def nest_data(groupers=self.groupers, prefix=[])
      groupers = groupers.dup
      group = groupers.pop

      group.group_values.map do |x|
        if groupers.any?
          { key: x, values: nest_data(groupers, [x]+prefix) }
        else
          values = []
          values.push *aggregators.collect { |name, aggregator| { key: name.to_s, value: ( raw_data[([x]+prefix+[name.to_s])] || aggregator.default_value ) } }
          values.push *calculators.collect { |name, calculator| { key: name.to_s, value: ( raw_data[([x]+prefix+[name.to_s])] || calculator.default_value ) } }

          { key: x, values: values }
        end
      end
    end

    def total
      results_hash = @total_data || total_report.raw_data

      results_hash.merge!(results_hash.collect do |row, value|
        calculators.collect do |name, calculator|
          row_data = hash_raw_row(row, value, ['totals'])
          calc_report = parent_report.total_report

          parent_row, parent_value = match_parent_row_for_calculator(row_data, calc_report, calculator)
          [['totals', name.to_s], calculator.evaluate(row_data, hash_raw_row(parent_row, parent_value, calc_report.grouper_names))] unless parent_row.nil?
        end
      end.flatten(1).to_h) unless parent_report.nil?

      results_hash
    end

    def validate_params!
      incomplete_msg = "You must declare at least one aggregator and one dimension to initialize a report. See the README for more details."
      raise Repor::InvalidParamsError, "#{self.class.name} doesn't have any aggregators declared! #{incomplete_msg}" if aggregators.empty?
      raise Repor::InvalidParamsError, "#{self.class.name} doesn't have any dimensions declared! #{incomplete_msg}" if dimensions.except(:totals).empty?
      raise Repor::InvalidParamsError, 'parent_report must be included in order to process calculations' if calculators.any? && parent_report.nil?

      (aggregators.keys - self.class.aggregators.keys).each do |aggregator|
        invalid_param!(:aggregator, "#{aggregator} is not a valid aggregator (should be in #{self.class.aggregators.keys})")
      end

      invalid_param!(:groupers, "one of #{grouper_names} is not a valid dimension (should all be in #{dimensions.keys})") unless groupers.all?(&:present?)
      invalid_param!(:parent_report, 'must be an instance of Repor::Report') unless parent_report.nil? || parent_report.kind_of?(Repor::Report)
      invalid_param!(:total_report, 'must be an instance of Repor::Report') unless @total_report.nil? || @total_report.kind_of?(Repor::Report)
    end

    def invalid_param!(param_key, message)
      raise InvalidParamsError, "Invalid value for params[:#{param_key}]: #{message}"
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
