require 'repor/aggregator/base'

module Repor
  module Tracker
    class Base < Repor::Aggregator::Base
      def aggregator
        opts[:aggregator] || name
      end
    end
  end
end
