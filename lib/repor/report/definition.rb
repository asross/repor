require 'repor/inflector'

module Repor
  class Report
    module Definition
      extend ActiveSupport::Concern

      METRICS = %i[aggregator calculator dimension tracker].collect do |type|
        metrics = Dir.glob(File.join(__dir__, '..', type.to_s, '*.rb')).collect { |file| File.basename(file, '.rb') }.without(*%w[base bin]).collect(&:to_sym).sort.freeze
        [type, const_set(type.to_s.upcase, metrics)]
      end.to_h.sort.freeze

      delegate :report_model, to: :class

      class_methods do
        # Dimensions define what we are reporting about. For example, some common dimensions would be the Name of the
        # data being reported on and the Date it happened, such as the Author name and the Published date of blog posts
        # in an online blog.
        # These dimension configurations are the data points that a report can be grouped by, data in the group will
        # all be aggregated together using the configured aggregators. Multiple dimension types are available for
        # different grouping methods.
        #
        # Category dimensions will do a normal GROUP BY on one specific field, this can also be used in conjunction
        # with a filter to limit the GROUP BY values returned.
        #
        # Bin dimensions group many rows into "bins" of a specified width, this is helpful when grouping by a datetime
        # value by allowing you to set this bin width to :days or :months. In addition to the Time dimension you can
        # use the Number dimensions with a bin, grouping numeric values into larger groups such as 10s or 100s.
        def dimension(name, dimension_class, opts = {})
          dimensions[name.to_sym] = { axis_class: dimension_class, opts: opts }
        end

        def dimensions
          @dimensions ||= { totals: { axis_class: Dimension::Category, opts: { _expression: "'totals'" } } }
        end

        # Aggregators calculate the statistical data for the report into each dimension group. After grouping the data
        # the aggregators calculate the values to be reported on. For example, if we use the dimensions Author name and
        # Published date of blog posts in an online blog, we can then use aggregators on the Likes value to get the Sum
        # of all Likes on all posts for each Published date for each Author name. There are multiple ways to aggregate
        # this data, and so multiple aggregator types are provided.
        #
        # Average aggregator would calculate the average value across all the data in the group.
        # 
        # Sum aggregator would calculate the sum total of all values across all the data in the group.
        #
        # Additional aggregators are also available for many other calculation types
        def aggregator(name, aggregator_class, opts = {})
          aggregators[name.to_sym] = { axis_class: aggregator_class, opts: opts }
        end

        def aggregators
          @aggregators ||= {}
        end

        # Calculators are special aggregators that perform calculations between report dimension data and a parent
        # report.
        # This could be used when generating a drill-down report with more specific data based on a specific row of a
        # different report, where the parent report has larger dimension bins or fewer dimensions defined. For example,
        # a parent report could group by Author only, and aggregate total Likes across all blog posts, the child report
        # could group by Author and Published to provided more specific details. A calculator could then calculate the
        # Ratio of Likes on a specific Published date vs the parent report's total Likes for that same specific Author.
        # It can also be used to calculate values between the report data and the Totals report data, where the Totals
        # report is the aggregation of all the data in the report combined. For example, if the report groups by Author
        # we can aggregate total Likes across all blog posts for each Author. The Totals report would aggregate total
        # Likes across all blog posts for all Author. A calculator can calculate the ratio of Total Likes vs the
        # Author's total Likes.
        #
        # A calculator only performs additional calculations on already aggregated data, so an :aggregator value
        # matching the aggregator name must be passed in the opts. Additionally, you may optionally pass a
        # :parent_aggregator if the name of this aggregator is different.
        def calculator(name, calculator_class, opts = {})
          calculators[name.to_sym] = { axis_class: calculator_class, opts: opts }
        end

        def calculators
          @calculators ||= {}
        end

        # Trackers are special aggregators that perform calculations between sequential bin dimension data. In order to
        # use a tracker the last dimension configured in your report must be a bin dimension that defines a bin width
        # so the tracker can determine the bin sequence. If a bin dimension with a bin width is not the last dimension
        # configured tracker data will not be calculated.
        # Any other dimensions are also considered when tracking data, if the value in any other dimension value
        # changes between two rows the tracker data is not calculated. For example, if dimensions Author and Published
        # are configured and an aggregator to sum Likes is configured, a tracker to calculate Likes delta may also be
        # used. Each Published date the delta will be calculated, as long as the previous row has a Published date
        # sequentially immediately adjacent to the current row. If the bin with is date, the dates 2020/06/05 and
        # 2020/06/06 are adjacent, but if there are no blog posts for 2020/06/07 then the dela will not be calculated
        # on the 2020/06/08 row since 2020/06/06 is not adjacent. Additionally, when the Author changes no delta will
        # be calculated, even if the Published date on the row is sequentially immediately adjacent.
        #
        # A tracker only performs additional calculations on already aggregated data, so an :aggregator value matching
        # the aggregator name must be passed in the opts.
        def tracker(name, trackers_class, opts = {})
          trackers[name.to_sym] = { axis_class: trackers_class, opts: opts }
        end

        def trackers
          @trackers ||= {}
        end

        def available_dimensions
          dimensions.keys
        end
        alias_method :available_groupers, :available_dimensions

        def available_aggregators
          aggregators.keys + calculators.keys + trackers.keys
        end

        METRICS.each do |type, mertics|
          mertics.each do |mertic|
            class_eval <<-METRIC_HELPERS, __FILE__, __LINE__ + 1
              def #{mertic}_#{type}(name, opts = {})
                #{type}(name, #{(type.to_s + '/' + mertic.to_s.singularize(:_gem_repor)).camelize.sub(/.*\./, "")}, opts)
              end
            METRIC_HELPERS
          end
        end

        def default_report_model
          name.demodulize.sub(/Report$/, '').constantize
        rescue NameError
          raise $!, "#{$!} cannot be used as `report_on` class, please configure `report_on` in the report class", $!.backtrace
        end

        def default_model
          name.demodulize.sub(/Report$/, '').constantize
        end

        def report_model
          @report_model ||= default_model
        end

        def report_on(class_or_name)
          @report_model = class_or_name.to_s.constantize
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
          report_model.columns.each(&method(:autoreport_column))
          count_aggregator(:count) if aggregators.blank?
        end

        # can override this method to skip or change certain column declarations
        def autoreport_column(column)
          return if column.name == report_model.primary_key

          name, reflection = report_model.reflections.find { |_, reflection| reflection.foreign_key == column.name }
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
