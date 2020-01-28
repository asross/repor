require 'repor/dimension/bin'

module Repor
  module Dimension
    class Number < Bin
      DEFAULT_BIN_COUNT = 10

      def validate_params!
        super

        if params.key?(:bin_width)
          invalid_param!(:bin_width, 'must be numeric') unless Repor.numeric?(params[:bin_width])
          invalid_param!(:bin_width, 'must be greater than 0') unless params[:bin_width].to_f > 0
        end
      end

      def bin_width
        case
        when params.key?(:bin_width)
          params[:bin_width].to_f
        when domain.zero?
          1
        when params.key?(:bin_count)
          domain / params[:bin_count].to_f
        else
          default_bin_width
        end
      end

      private

      def default_bin_width
        domain / default_bin_count.to_f
      end

      def default_bin_count
        self.class::DEFAULT_BIN_COUNT
      end

      class Set < Bin::Set
        def parses?(value)
          Repor.numeric?(value)
        end

        def parse(value)
          value.to_f
        end
      end
    end
  end
end
