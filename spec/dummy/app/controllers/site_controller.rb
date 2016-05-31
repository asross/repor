class SiteController < ApplicationController
  def report
    @report = PostReport.new(params.fetch(:post_report, {}))
    @csv = Repor::Serializers::CsvSerializer.new(@report)

    respond_to do |format|
      format.html
      format.csv { send_data(csv.csv_text, filename: csv.filename) }
    end
  end
end
