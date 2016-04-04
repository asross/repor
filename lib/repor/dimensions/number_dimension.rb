module Repor
  module Dimensions
    class NumberDimension < BinDimension
      def validate_params!
        super

        if params.key?(:bin_width)
          unless Repor.numeric?(params[:bin_width])
            invalid_param!(:bin_width, "must be numeric")
          end

          unless params[:bin_width].to_f > 0
            invalid_param!(:bin_width, "must be greater than 0")
          end
        end
      end

      def bin_width
        if params.key?(:bin_width)
          params[:bin_width].to_f
        elsif domain == 0
          1
        elsif params.key?(:bin_count)
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
        10
      end

      class Bin < BinDimension::Bin
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
