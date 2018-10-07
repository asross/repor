require 'repor/invalid_params_error'

module Repor
  class Report
    module Validation
      def validate_params!
        validate_configuration!
        validate_aggregators!
        validate_groupers!
        validate_parent_report!
        validate_total_report!
      end

      def validate_configuration!
        incomplete_message = ['You must declare at least one aggregator or tracker, and at lease one dimension to initialize a report', 'See the README for more details']
        raise Repor::InvalidParamsError, ["#{self.class.name} does not declare any aggregators or trackers"].concat(incomplete_message).join(". ") if aggregators.empty?
        raise Repor::InvalidParamsError, ["#{self.class.name} does not declare any dimensions"].concat(incomplete_message).join(". ") if dimensions.except(:totals).empty?
        raise Repor::InvalidParamsError, 'parent_report must be included in order to process calculations' if calculators.any? && parent_report.nil?
      end

      def validate_aggregators!
        (aggregators.keys - self.class.aggregators.keys).each do |aggregator|
          invalid_param!(:aggregator, "#{aggregator} is not a valid aggregator (should be in #{self.class.aggregators.keys})")
        end
      end

      def validate_groupers!
        unless groupers.all?(&:present?)
          invalid_groupers = grouper_names.zip(groupers).collect { |k,v| k if v.nil? }.compact
          invalid_groupers_message = [
            [invalid_groupers.to_sentence, (invalid_groupers.one? ? 'is not a' : 'are not'), 'valid', 'dimension'.pluralize(invalid_groupers.count)].join(' '),
            "declared dimension include #{dimensions.keys.to_sentence}"
          ].join(". ")
          invalid_param!(:groupers, invalid_groupers_message)
        end
      end

      def validate_parent_report!
        invalid_param!(:parent_report, 'must be an instance of Repor::Report') unless parent_report.nil? || parent_report.kind_of?(Repor::Report)
      end

      def validate_total_report!
        invalid_param!(:total_report, 'must be an instance of Repor::Report') unless @total_report.nil? || @total_report.kind_of?(Repor::Report)
      end

      def invalid_param!(param_key, message)
        raise Repor::InvalidParamsError, "Invalid value for params[:#{param_key}]: #{message}"
      end
    end
  end
end
