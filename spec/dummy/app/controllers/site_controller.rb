class SiteController < ApplicationController
  def report
    @report = PostReport.new(report_params)

    respond_to do |format|
      format.html
      format.csv { send_data(csv.csv_text, filename: csv.filename) }
    end
  end

  private

  def csv
    @csv ||= Repor::Serializers::CsvSerializer.new(@report)
  end

  def report_params
    raw_params = params.fetch(:post_report, {})
    Repor::Serializers::FormFieldSerializer.sanitize_params(raw_params)
  end
end
