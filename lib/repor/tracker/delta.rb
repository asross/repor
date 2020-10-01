module Repor
  module Tracker
    class Delta < Repor::Tracker::Base
      def track(row, prior_row)
        ((row[aggregator].to_f / prior_row[prior_aggregator].to_f) * 100) unless row.nil? || prior_row.nil? || prior_row[prior_aggregator].to_f == 0
      end
    end
  end
end
