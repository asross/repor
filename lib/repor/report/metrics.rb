module Repor
  class Report
    module Metrics
      delegate :table_name, to: :report_model

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
        params.fetch(:relation, report_model.all)
      end

      def relation
        @relation ||= relators.reduce(base_relation) { |relation, dimension| dimension.relate(relation) }
      end

      def records
        @records ||= filters.reduce(relation) { |relation, dimension| dimension.filter(relation) }
      end

      def groups
        @groups ||= groupers.reduce(records) { |relation, dimension| dimension.group(relation) }
      end

      def calculators
        @calculators ||= build_axes(self.class.calculators.slice(*Array(params[:calculators]).collect(&:to_sym)))
      end

      def trackers
        @trackers ||= build_axes(self.class.trackers.slice(*Array(params[:trackers]).collect(&:to_sym)))
      end

      def fields
        [groupers, aggregate_fields].inject(&:merge)
      end

      def total_report
        @total_report ||= self.class.new(@params.except(:calculators).merge({ groupers: :totals })) unless @total_data.present?
      end

      private

      def build_axes(axes)
        axes.map { |name, h| [name, h[:axis_class].new(name, self, h[:opts])] }.to_h
      end
    end
  end
end
