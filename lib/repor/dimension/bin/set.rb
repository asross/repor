module Repor
  module Dimension
    class Bin
      class Set
        class << self
          def from_hash(source)
            # Returns either a bin or nil, depending on whether the input is valid.
            case source
            when nil
              new(nil, nil)
            when Hash then
              min, max = source.symbolize_keys.values_at(:min, :max)
              new(min.presence, max.presence) unless min.blank? && max.blank?
            else
              nil
            end
          end

          def from_sql(value)
            case value
            when /^([^,]+),(.+)$/ then new($1, $2)
            when /^([^,]+),$/     then new($1, nil)
            when /^,(.+)$/        then new(nil, $1)
            when ',', nil         then new(nil, nil)
            else
              raise "Unexpected SQL bin format #{value}"
            end
          end
        end

        def initialize(min, max)
          @min = min
          @max = max
        end

        def min
          @min && parse(@min)
        end

        def max
          @max && parse(@max)
        end

        def valid?
          (@min.nil? || parses?(@min)) && (@max.nil? || parses?(@max))
        end

        def parses?(value)
          parse(value).present? rescue false
        end

        def parse(value)
          value
        end

        def quote(value)
          ActiveRecord::Base.connection.quote(value)
        end

        def cast(value)
          quote(value)
        end

        def bin_text
          "#{min},#{max}"
        end

        def cast_bin_text
          case Repor.database_type
          when :postgres, :sqlite
            "CAST(#{quote(bin_text)} AS text)"
          else
            quote(bin_text)
          end
        end

        def row_sql
          "SELECT #{cast(min)} AS min, #{cast(max)} AS max, #{cast_bin_text} AS bin_text"
        end

        def contains_sql(expr)
          case bin_edges
          when :min_and_max
            "(#{expr} >= #{quote(min)} AND #{expr} < #{quote(max)})"
          when :min
            "#{expr} >= #{quote(min)}"
          when :max
            "#{expr} < #{quote(max)}"
          else
            "#{expr} IS NULL"
          end
        end

        def as_json(*)
          @as_json ||= case bin_edges
          when :min_and_max
            { min: min, max: max }
          when :min
            { min: min }
          when :max
            { max: max }
          end
        end

        def [](key)
          case key.to_s
          when 'min' then min
          when 'max' then max
          end
        end

        def has_key?(key)
          %w[min max].include?(key.to_s)
        end
        alias key? has_key?

        def values_at(*keys)
          keys.map { |k| self[key] }
        end

        def inspect
          "<Bin @min=#{min.inspect} @max=#{max.inspect}>"
        end

        def hash
          as_json.hash
        end

        def ==(other)
          if other.nil?
            min.nil? && max.nil?
          else
            min == other[:min] && max == other[:max]
          end
        end
        alias eql? ==

        def bin_edges
          case 
          when min_and_max? then :min_and_max
          when min? then :min
          when max? then :max
          end
        end

        private

        def min_and_max?
          min.present? && max.present?
        end

        def min?
          min.present?
        end

        def max?
          max.present?
        end
      end
    end
  end
end
