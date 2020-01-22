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

      def source_data
        @source_data ||= aggregators.values.reduce(groups) do |relation, aggregator|
          # append each aggregator into the base relation (groups)
          relation.merge(aggregator.aggregate(base_relation))
        end
      end

      private

      def aggregate        
        tracker_dimension_key = :_tracker_dimension

        if trackable? && trackers.any?
          prior_obj = prior_bin_report.source_data.first
          prior_row = prior_bin_report.hashed_data.first.with_indifferent_access

          results_key_prefix = groupers.map { |g| g.extract_sql_value(prior_obj) }
          prior_row[tracker_dimension_key] = results_key_prefix[0..-2]
        else
          prior_obj = nil
          prior_row = {}
        end

        source_data.each_with_object({}) do |current_obj, results|
          # collect all group values and append to results
          # for the results we store and use as the key prefix for each value
          results_key_prefix = groupers.map { |g| g.extract_sql_value(current_obj) }
          # for the current_row appended as individual keys and values to the data object
          current_row = groupers.collect(&:name).zip(results_key_prefix).to_h.with_indifferent_access

          # collect all aggregator fields into the results from each current_obj in the base relation
          aggregators.each do |name, aggregator|
            aggregated_value = current_obj.attributes[aggregator.sql_value_name] || aggregator.default_value
            results[results_key_prefix + [name.to_s]] = aggregated_value
            current_row[name.to_s] = aggregated_value
          end

          # append all calculator fields
          if calculable?
            calculators.each do |name, calculator|
              calc_report = calculator.totals? ? parent_report.total_report : parent_report

              parent_row = match_parent_row_for_calculator(current_row, calc_report, calculator)
              next if parent_row.nil?

              calculated_value = calculator.calculate(current_row, parent_row) || calculator.default_value
              results[results_key_prefix + [name.to_s]] = calculated_value
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
            current_row[tracker_dimension_key] = results_key_prefix[0..-2]

            if current_row[tracker_dimension_key] == prior_row[tracker_dimension_key] && bins_are_adjacent?(current_obj, prior_obj)
              trackers.each do |name, tracker|
                calculated_value = tracker.track(current_row, prior_row) || tracker.default_value
                results[results_key_prefix + [name.to_s]] = calculated_value
                current_row[name.to_s] = calculated_value
              end
            end
          end

          prior_obj, prior_row = current_obj, current_row
        end
      end

      def flatten_data
        group_values.each_with_object({}) do |group, results|
          aggregators.map do |name, aggregator|
            aggregator_group = group + [name.to_s]
            results[aggregator_group] = (raw_data[aggregator_group] || aggregator.default_value)
          end

          calculators.each do |name, calculator|
            calculator_group = group + [name.to_s]
            results[calculator_group] = calculable? ? (raw_data[calculator_group] || calculator.default_value) : nil
          end

          
          trackers.each do |name, tracker|
            tracker_group = group + [name.to_s]
            results[tracker_group] = trackable? ? (raw_data[tracker_group] || tracker.default_value) : nil
          end
        end
      end

      def hash_data
        group_values.collect do |group|
          grouper_names.zip(group).to_h.tap do |row|
            aggregators.each do |name, aggregator|
              row[name] = (raw_data[group + [name.to_s]] || aggregator.default_value)
            end

            calculators.each do |name, calculator|
              row[name] = calculable? ? (raw_data[group + [name.to_s]] || calculator.default_value) : nil
            end

            trackers.each do |name, tracker|
              row[name] = trackable? ? (raw_data[group + [name.to_s]] || tracker.default_value) : nil
            end
          end
        end
      end

      def nest_data(groupers = self.groupers, prefix = [])
        nest_groupers = groupers.dup
        group = nest_groupers.pop

        group.group_values.map do |group_value|
          value_prefix = [group_value] + prefix
          values = []

          if nest_groupers.any?
            values = nest_data(nest_groupers, value_prefix)
          else
            aggregators.each do |name, aggregator|
              value = raw_data[value_prefix+[name.to_s]] || aggregator.default_value
              values.push({ key: name.to_s, value: value })
            end

            calculators.each do |name, calculator|
              value = calculable? ? (raw_data[value_prefix+[name.to_s]] || calculator.default_value) : nil
              values.push({ key: name.to_s, value: value })
            end

            trackers.each do |name, tracker|
              value = trackable? ? (raw_data[value_prefix+[name.to_s]] || tracker.default_value) : nil
              values.push({ key: name.to_s, value: value })
            end
          end

          { key: group_value, values: values }
        end
      end

      def total
        results = @total_data || total_report.raw_data

        results.merge!(results.collect do |row, value|
          calculators.collect do |name, calculator|
            row_data = hash_raw_row(row, value, ['totals'])
            calc_report = parent_report.total_report

            parent_row = match_parent_row_for_calculator(row_data, calc_report, calculator)
            [['totals', name.to_s], calculator.calculate(row_data, parent_row)] unless parent_row.nil?
          end
        end.flatten(1).to_h) unless parent_report.nil?

        results
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
        parent_report.hashed_data.detect { |parent_row_data| parent_groupers.all? { |g| row_data[g] == parent_row_data[g] } }
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
        return false if [bin_a.min, bin_a.max, bin_b.min, bin_b.max].compact.none?

        # Check if either dimension's min matches the other's max
        bin_a.min == bin_b.max || bin_b.min == bin_a.max
      end

      def calculable?
        @calculable ||= parent_report.present?
      end

      def trackable?
        @trackable ||= tracker_dimension.is_a?(Repor::Dimension::Bin) && tracker_dimension.min.present?
      end

      def tracker_dimension
        @tracker_dimension ||= groupers.last
      end

      def prior_bin_report
        @prior_bin_report ||= if trackable? && trackers.any?
          first_bin_min = tracker_dimension.group_values.first.min
          prior_bin_params = {
            dimensions: { tracker_dimension.name => { only: { min: (first_bin_min - tracker_dimension.bin_width), max: first_bin_min }}},
            trackers: nil
          }
          tracker_report_params = params.deep_merge(prior_bin_params)
          self.class.new(params.merge(tracker_report_params))
        end
      end
    end
  end
end
