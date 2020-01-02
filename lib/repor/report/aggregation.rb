module Repor
  class Report
    module Aggregation
      def raw_data
        @raw_data ||= aggregate
      end

      # flat hash of
      # { [x1, x2, x3] => y }
      def flat_data
        @flat_data ||= flatten_data
      end

      def hashed_data
        @hashed_data ||= hash_data
      end

      # nested array of
      # [{ key: x3, values: [{ key: x2, values: [{ key: x1, value: y }] }] }]
      def nested_data
        @nested_data ||= nest_data
      end
      alias_method :data, :nested_data

      def total_data
        @total_data ||= total
      end
      alias_method :totals, :total_data

      private

      def aggregate
        prior_row = nil

        aggregators.values.reduce(groups) do |relation, aggregator|
          # append each aggregator into the base relation (groups)
          relation.merge(aggregator.aggregate(base_relation))
        end.each_with_object({}) do |obj, results_hash|
          results_hash_key_prefix = groupers.map { |g| g.extract_sql_value(obj) }
          current_row = {}

          # collect all aggregator fields into the results_hash from each obj in the base relation
          aggregators.each do |name, aggregator|
            aggregated_value = obj.attributes[aggregator.sql_value_name] || aggregator.default_value
            results_hash[results_hash_key_prefix + [name.to_s]] = aggregated_value
            current_row[name.to_s] = aggregated_value
          end

          # append all calculator fields 
          if parent_report.present?
            row_data = dimensions.keys.zip(dimensions.values.collect { |dimension| obj.attributes[dimension.send(:sql_value_name)] }).to_h
            row_data.merge!(aggregators.keys.zip(aggregators.values.collect { |aggregator| obj.attributes[aggregator.sql_value_name] || aggregator.default_value }).to_h)
            row_data.symbolize_keys!

            calculators.each do |name, calculator|
              calc_report = calculator.totals? ? parent_report.total_report : parent_report
              
              parent_row, parent_value = match_parent_row_for_calculator(row_data, calc_report, calculator)
              next if parent_row.nil?

              calculated_value = calculator.evaluate(row_data, hash_raw_row(parent_row, parent_value, calc_report.grouper_names)) || calculator.default_value
              results_hash[results_hash_key_prefix + [name.to_s]] = calculated_value
              current_row[name.to_s] = calculated_value
            end
          end

          # append all tracker fields 
          # next if parent_report.present?


          #   order_expression


          #   row_data = dimensions.keys.zip(dimensions.values.collect { |dimension| obj.attributes[dimension.send(:sql_value_name)] }).to_h
          #   row_data.merge!(aggregators.keys.zip(aggregators.values.collect { |aggregator| obj.attributes[aggregator.sql_value_name] || aggregator.default_value }).to_h)
          #   row_data.symbolize_keys!

          #   calculators.each do |name, calculator|
          #     calc_report = calculator.totals? ? parent_report.total_report : parent_report
              
          #     parent_row, parent_value = match_parent_row_for_calculator(row_data, calc_report, calculator)
          #     next if parent_row.nil?

          #     calculated_value = calculator.evaluate(row_data, hash_raw_row(parent_row, parent_value, calc_report.grouper_names)) || calculator.default_value
          #     results_hash[results_hash_key_prefix + [name.to_s]] = calculated_value
          #     current_row[name.to_s] = calculated_value
          #   end
          # end

          prior_row = current_row
        end
      end

      def flatten_data
        group_values.map do |group|
          aggregators.map do |name, aggregator|
            aggregator_group = group + [name.to_s]
            [aggregator_group, (raw_data[aggregator_group] || aggregator.default_value)]
          end
        end.flatten(1).to_h
      end

      def hash_data
        group_values.collect do |group|
          grouper_names.zip(group).to_h.tap do |row|
            aggregators.each { |name, aggregator| row[name] = (raw_data[group + [name.to_s]] || aggregator.default_value) }
          end
        end
      end

      def nest_data(groupers = self.groupers, prefix = [])
        groupers = groupers.dup
        group = groupers.pop

        group.group_values.map do |group_value|
          if groupers.any?
            { key: group_value, values: nest_data(groupers, [group_value]+prefix) }
          else
            values = aggregators.collect { |name, aggregator| { key: name.to_s, value: ( raw_data[([group_value]+prefix+[name.to_s])] || aggregator.default_value ) } }
            values.concat calculators.collect { |name, calculator| { key: name.to_s, value: ( raw_data[([group_value]+prefix+[name.to_s])] || calculator.default_value ) } }

            { key: group_value, values: values }
          end
        end
      end

      def total
        results_hash = @total_data || total_report.raw_data

        results_hash.merge!(results_hash.collect do |row, value|
          calculators.collect do |name, calculator|
            row_data = hash_raw_row(row, value, ['totals'])
            calc_report = parent_report.total_report

            parent_row, parent_value = match_parent_row_for_calculator(row_data, calc_report, calculator)
            [['totals', name.to_s], calculator.evaluate(row_data, hash_raw_row(parent_row, parent_value, calc_report.grouper_names))] unless parent_row.nil?
          end
        end.flatten(1).to_h) unless parent_report.nil?

        results_hash
      end

      def group_values
        @group_values ||= all_combinations_of(groupers.map(&:group_values))
      end

      def all_combinations_of(values)
        values[0].product(*values[1..-1])
      end

      def hash_raw_row(row, value, grouper_names)
        grouper_names.dup.push(:dimension, :value).zip(row.dup.push(value)).to_h.tap do |row_hash|
          row_hash[row_hash.delete(:dimension)] = row_hash.delete(:value)
          row_hash.symbolize_keys!
        end
      end

      def match_parent_row_for_calculator(row_data, parent_report, calculator)
        parent_report.flat_data.detect do |parent_row, parent_value|
          parent_row_data = hash_raw_row(parent_row, parent_value, parent_report.grouper_names)
          parent_groupers.all? { |g| row_data[g] == parent_row_data[g] } && parent_row_data.include?(calculator.field.to_sym)
        end
      end
      
    end
  end
end
