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
        prior_row = {}
        prior_obj = nil
        tracker_dimension_key = :_tracker_dimension

        aggregators.values.reduce(groups) do |relation, aggregator|
          # append each aggregator into the base relation (groups)
          relation.merge(aggregator.aggregate(base_relation))
        end.each_with_object({}) do |current_obj, results_hash|
          results_hash_key_prefix = groupers.map { |g| g.extract_sql_value(current_obj) }
          current_row = { tracker_dimension_key => results_hash_key_prefix[0..-2] }

          # collect all aggregator fields into the results_hash from each current_obj in the base relation
          aggregators.each do |name, aggregator|
            aggregated_value = current_obj.attributes[aggregator.sql_value_name] || aggregator.default_value
            results_hash[results_hash_key_prefix + [name.to_s]] = aggregated_value
            current_row[name.to_s] = aggregated_value
          end

          row_data = dimensions.keys.zip(dimensions.values.collect { |dimension| current_obj.attributes[dimension.send(:sql_value_name)] }).to_h
          row_data.merge!(aggregators.keys.zip(aggregators.values.collect { |aggregator| current_obj.attributes[aggregator.sql_value_name] || aggregator.default_value }).to_h)
          row_data.symbolize_keys!

          # append all calculator fields
          if calculable?
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
          # Trackers can only be applied if the last grouper is a bin dimension, since bin dimensions are series of the
          # same data set with a pre-defined sequence. Bin dimension results also allow us to determine if an empty set
          # is present, because the bins are pre-defined.
          # If additional demensions are included the trackers reset each time these groups change. For example, if the
          # category dimension "author.id" and time dimension "created_at" with bin_width "day" are used, each time the
          # "author.id" value (bin) changes the tracker is reset so we do not track changes from the last day of each
          # "author.id" to the first day of the next "author.id".
          if trackable?
            if current_row[tracker_dimension_key] == prior_row[tracker_dimension_key] && bins_are_adjacent?(current_obj, prior_obj)
              trackers.each do |name, tracker|


                # TODO:
                # Add specs to excercise this code and validate it's working

                calculated_value = tracker.evaluate(row_data, prior_row) || tracker.default_value
                puts calculated_value.inspect
                results_hash[results_hash_key_prefix + [name.to_s]] = calculated_value
                current_row[name.to_s] = calculated_value
              end
            end
          end

          prior_obj, prior_row = current_obj, current_row.merge(row_data)
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

      def bins_are_adjacent?(obj_a, obj_b, dimension = tracker_dimension)
        return false if obj_a.nil? || obj_b.nil?

        # Categories are not sequential, even if they appear to be. Instead, a category is a group by on a specific
        # field with identical values. If the field type is integer we can deduce the bin width to be 1, but if the
        # type is string or float the the width is less evident.
        # For example, if the field is float and the first value is 1.0 should the next sequential value be 1.1? What
        # if we have 1.0001? Should we skip 1.0002 if it does not exist and skip right to 1.01? What if we habe 1.0,
        # 1.1, 1.11, and 1.13 but no 1.12? So we determine that 1.13 is sequentially after 1.11 or de we reset the
        # tracker? Even if there is a "correct" method for one report it may not be correct for a different report. The
        # same problem applies to strings. Which character is after "z"? The ASCII hex value is "{", which would work
        # fine for ordering, but maybe not for determining when a tracker should be reset. Additionally, we need to
        # deal with strings of different lengths. Alphabetically you could order 'A', 'AA', 'AAA', 'B' but how do know
        # when to reset the tracker? If we get a new value of 'AAAA' we have entirelly new values used to calculate the
        # tracker value for the 'B' row, effectivally making the tracker values irrelevent.
        # Even going back to the integer example, the value allowed to be stored increments by 1, but there is no
        # guerentee that these are the actual values being used in the field.
        # For these reasons we will not attempt to track any dimension that does not specifically specify a bin width.
        
        # Any class that inherits from Bin will be evaluated, this includes both Number and Time classes, all other
        # classes will be skipped.
        return false unless dimension.is_a?(Repor::Dimension::Bin)

        bin_a = dimension.extract_sql_value(obj_a)
        bin_b = dimension.extract_sql_value(obj_b)

        # Do not find identical dimensions adjacent
        return false if bin_a.min == bin_b.min && bin_b.max == bin_a.max

        # Do not find two undefined dimensions adjacent
        return false if [bin_a.min, bin_a.max, bin_b.min, bin_b.max].compact.any?

        # Check if either dimension's min matches the other's max
        bin_a.min == bin_b.max || bin_b.min == bin_a.max
      end

      def calculable?
        @calculable ||= parent_report.present?
      end

      def trackable?
        @trackable ||= tracker_dimension.is_a?(Repor::Dimension::Bin)
      end

      def tracker_dimension
        @tracker_dimension ||= groupers.last
      end
    end
  end
end
