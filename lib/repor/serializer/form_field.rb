module Repor
  module Serializer
    class FormField < Base
      include ActionView::Helpers::FormTagHelper
      include ActionView::Helpers::FormOptionsHelper

      def html_fields
        "<div class='#{wrapper_class}'>
          #{axis_fields}
          #{dimension_fields.join}
        </div>".html_safe
      end

      def aggregator_options
        @agg_opts ||= report.aggregators.map { |name, agg| [human_aggregator_label(agg), name] }
      end

      def dimension_options
        @dim_opts ||= report.dimensions.map { |name, dim| [human_dimension_label(dim), name] }
      end

      def aggregator_field
        select_tag("#{prefix}[aggregator]", options_for_select(aggregator_options, report.aggregators.keys.first))
      end

      def primary_grouper_field
        select_tag("#{prefix}[groupers][0]", options_for_select(dimension_options, report.grouper_names[0]))
      end

      def secondary_grouper_field
        select_tag("#{prefix}[groupers][1]", options_for_select([[nil, nil]]+dimension_options, report.grouper_names[1]))
      end

      def axis_fields
        "<div class='#{axis_fields_class}'>
          Show me #{aggregator_field}
          by #{primary_grouper_field}
          and #{secondary_grouper_field}
          for
        </div>".html_safe
      end

      def dimension_fields
        report.dimensions.map { |name, dimension| field_for(dimension) }.compact
      end

      def field_for(dimension)
        case dimension
        when Repor::Dimension::Category then category_dimension_field(dimension)
        when Repor::Dimension::Set then bin_dimension_field(dimension)
        end
      end

      def category_dimension_field(dimension)
        options = [[nil, nil]]

        dimension.all_values.each do |value|
          options << [human_dimension_value_label(dimension, value), value]
        end

        fields_for(dimension) do
          select_tag("#{prefix_for(dimension)}[only]", options_for_select(options, dimension.filter_values.first))
        end
      end

      def bin_dimension_field(dimension)
        fields_for(dimension) do
          fields = "#{bin_min_field(dimension)} to #{bin_max_field(dimension)}"
          fields += " by #{bin_step_field(dimension)}" if dimension.grouping?
          fields
        end
      end

      def bin_min_field(dimension)
        text_field_tag("#{prefix_for(dimension)}[only][min]", dimension.filter_min, placeholder: bin_min_placeholder(dimension))
      end

      def bin_max_field(dimension)
        text_field_tag("#{prefix_for(dimension)}[only][max]", dimension.filter_max, placeholder: bin_max_placeholder(dimension))
      end

      def bin_step_field(dimension)
        text_field_tag("#{prefix_for(dimension)}[bin_width]", dimension.params[:bin_width], placeholder: bin_step_placeholder(dimension))
      end

      def fields_for(dimension, &block)
        "<fieldset class='#{dimension_fields_class(dimension)}'>
          <legend>#{human_dimension_label(dimension)}</legend>
          #{yield}
        </fieldset>".html_safe
      end

      def wrapper_class
        "repor-fields repor-fields--#{css_class(report.class.name)}"
      end

      def axis_fields_class
        'repor-axis-fields'
      end

      def dimension_fields_class(dimension)
        [
          'repor-dimension-fields',
          "repor-dimension-fields--#{css_class(dimension.name)}",
          "repor-dimension-fields--#{css_class(dimension.class.name)}"
        ].join(' ')
      end

      def bin_max_placeholder(dimension)
        'max'
      end

      def bin_min_placeholder(dimension)
        'min'
      end

      def bin_step_placeholder(dimension)
        dimension.bin_width.inspect
      end

      def prefix
        report.class.name.underscore
      end

      def prefix_for(dimension)
        "#{prefix}[dimensions][#{dimension.name}]"
      end

      def css_class(s)
        s.to_s.demodulize.underscore.dasherize
      end
    end
  end
end
