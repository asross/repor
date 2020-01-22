require 'repor/inflector'
require 'repor/invalid_params_error'

module Repor
  class Report
    module Validation
      attr_accessor :errors

      def validate_params!
        validate_configuration!
        validate_aggregators!
        validate_groupers!
        validate_calculators!
        validate_trackers!
        validate_parent_report!
        validate_total_report!

        raise_invalid_params_error! if errors.present? && errors.any?
      end

      def validate_configuration!
        incomplete_message = ['You must declare at least one aggregator or tracker, and at lease one dimension to initialize a report', 'See the README for more details']

        raise Repor::InvalidParamsError, ["#{self.class.name} does not declare any aggregators or trackers"].concat(incomplete_message).join(". ") if aggregators.empty?
        raise Repor::InvalidParamsError, ["#{self.class.name} does not declare any dimensions"].concat(incomplete_message).join(". ") if dimensions.except(:totals).empty?
        raise Repor::InvalidParamsError, 'parent_report must be included in order to process calculations' if calculators.any? && parent_report.nil?
      end

      def validate_aggregators!
        (aggregators.keys - self.class.aggregators.keys).each do |aggregator|
          add_invalid_param_error(:aggregator, ":#{aggregator} is not a valid aggregator (should be in #{self.class.aggregators.keys})")
        end
      end

      def validate_calculators!
        (calculators.keys - self.class.calculators.keys).each do |calculator|
          add_invalid_param_error(:calculator, ":#{calculator} is not a valid calculator (should be in #{self.class.calculators.keys})")
        end

        calculators.values.each do |calculator|
          if calculator.aggregator.nil?
            add_invalid_param_error(:calculator, ":#{calculator.name} must define an aggregator (should be in #{self.class.aggregator.keys})")
          elsif aggregators.exclude?(calculator.aggregator)
            add_invalid_param_error(:calculator, ":#{calculator.name} defines an valid aggregator :#{calculator.aggregator} (should be in #{self.class.aggregators.keys})")
          end
        end
      end

      def validate_trackers!
        (trackers.keys - self.class.trackers.keys).each do |tracker|
          add_invalid_param_error(:tracker, ":#{tracker} is not a valid tracker (should be in #{self.class.trackers.keys})")
        end

        trackers.values.each do |tracker|
          if tracker.aggregator.nil?
            add_invalid_param_error(:tracker, ":#{tracker.name} must define an aggregator (should be in #{self.class.aggregator.keys})")
          elsif aggregators.exclude?(tracker.aggregator)
            add_invalid_param_error(:tracker, ":#{tracker.name} defines an valid aggregator :#{tracker.aggregator} (should be in #{self.class.aggregators.keys})")
          end
        end
      end

      def validate_groupers!
        unless groupers.all?(&:present?)
          invalid_groupers = grouper_names.zip(groupers).collect { |k,v| k if v.nil? }.compact
          invalid_groupers_message = [
            [
              invalid_groupers.to_sentence,
              (invalid_groupers.one? ? 'is not a' : 'are not'), 'valid', 'dimension'.pluralize(invalid_groupers.count, :_gem_repor)
            ].join(' '),
            "declared dimension include #{dimensions.keys.to_sentence}"
          ].join(". ")
          add_invalid_param_error(:groupers, invalid_groupers_message)
        end
      end

      def validate_parent_report!
        add_invalid_param_error(:parent_report, 'must be an instance of Repor::Report') unless parent_report.nil? || parent_report.kind_of?(Repor::Report)
      end

      def validate_total_report!
        add_invalid_param_error(:total_report, 'must be an instance of Repor::Report') unless @total_report.nil? || @total_report.kind_of?(Repor::Report)
      end

      private

      def add_error(message)
        self.errors ||= []
        self.errors.push(message)
      end

      def add_invalid_param_error(param_key, message)
        self.errors ||= []
        self.errors.push("Invalid value for params[:#{param_key}]: #{message}")
      end

      def raise_invalid_params_error!
        raise Repor::InvalidParamsError, error_message
      end

      def error_message
        (["The report configuration contains the following #{'error'.pluralize(errors.count, :_gem_repor)}:"] + errors).join("\n - ")
      end
    end
  end
end
