module Repor
  class Report
    module Definition
      extend ActiveSupport::Concern

      METRICS = %i[aggregator calculator dimension tracker].collect do |type|
        metrics = Dir.glob(File.join(__dir__, '..', type.to_s, '*.rb')).collect { |file| File.basename(file, '.rb') }.without(*%w[base bin]).collect(&:to_sym).sort.freeze
        [type, const_set(type.to_s.upcase, metrics)]
      end.to_h.sort.freeze

      delegate :report_class, to: :class

      class_methods do
        def aggregator(name, aggregator_class, opts = {})
          aggregators[name.to_sym] = { axis_class: aggregator_class, opts: opts }
        end

        def aggregators
          @aggregators ||= {}
        end

        def calculator(name, calculator_class, opts = {})
          calculators[name.to_sym] = { axis_class: calculator_class, opts: opts }
        end

        def calculators
          @calculators ||= {}
        end

        def dimension(name, dimension_class, opts = {})
          dimensions[name.to_sym] = { axis_class: dimension_class, opts: opts }
        end

        def dimensions
          @dimensions ||= { totals: { axis_class: Dimension::Category, opts: { expression: "'totals'" } } }
        end

        def trackers(name, trackers_class, opts = {})
          trackers[name.to_sym] = { axis_class: trackers_class, opts: opts }
        end

        def trackers
          @trackers ||= {}
        end

        METRICS.each do |type, mertics|
          mertics.each do |mertic|
            class_eval <<-METRIC_HELPERS, __FILE__, __LINE__ + 1
              def #{mertic}_#{type}(name, opts = {})
                #{type}(name, #{(type.to_s + '/' + mertic.to_s).classify}, opts)
              end
            METRIC_HELPERS
          end
        end

        def default_report_class
          self.name.demodulize.sub(/Report$/, '').constantize
        rescue NameError
          raise $!, "#{$!} cannot be used as `report_on` class, please configure `report_on` in the report class", $!.backtrace
        end

        def report_class
          @report_class ||= default_class
        end

        def report_on(class_or_name)
          @report_class = class_or_name.to_s.constantize
        rescue NameError
          raise $!, "#{$!} cannot be used as `report_on` class", $!.backtrace
        end

        # ensure subclasses gain any aggregators or dimensions defined on their parents
        def inherited(subclass)
          instance_values.each { |var, val| subclass.instance_variable_set(:"@#{var}", val.dup) }
        end

        # autoreporting will automatically define dimensions based on columns
        def autoreport_on(class_or_name)
          report_on class_or_name
          report_class.columns.each(&method(:autoreport_column))
          count_aggregator(:count) if aggregators.blank?
        end

        # can override this method to skip or change certain column declarations
        def autoreport_column(column)
          return if column.name == report_class.primary_key

          name, reflection = report_class.reflections.find { |_, reflection| reflection.foreign_key == column.name }
          case
          when reflection.present?
            column_name = (reflection.klass.column_names & autoreport_association_name_columns(reflection)).first
            if column_name.present?
              category_dimension name, expression: "#{reflection.klass.table_name}.#{column_name}", relation: ->(r) { r.joins(name) }
            else
              category_dimension column.name
            end
          when %i[datetime timestamp time date].include?(column.type)
            time_dimension column.name
          when %i[integer float decimal].include?(column.type)
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
    end
  end
end
