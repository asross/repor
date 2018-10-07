Dir.glob(File.join(__dir__, 'report', '*.rb')).each { |file| require file }

module Repor
  class Report
    include Repor::Report::Definition
    include Repor::Report::Validation
    include Repor::Report::Metrics
    include Repor::Report::Aggregation    

    attr_reader :params, :parent_report, :parent_groupers

    def initialize(params = {})
      @params = params.deep_symbolize_keys.deep_dup.compact
      strip_blanks(@params) unless @params[:strip_blanks] == false
      DeeplyEnumerable::Hash.deep_compact(@params)

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

    private

    def strip_blanks(hash)
      hash.delete_if do |_, value|
        case value
        when Hash then strip_blanks(value)
        when Array then value.reject! { |v| v.try(:blank?) }
        else value
        end.try(:blank?)
      end
    end
  end
end
