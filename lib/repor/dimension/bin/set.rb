module Repor
  module Dimension
    class Bin
      class Set
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
          if min && max
            "(#{expr} >= #{quote(min)} AND #{expr} < #{quote(max)})"
          elsif max
            "#{expr} < #{quote(max)}"
          elsif min
            "#{expr} >= #{quote(min)}"
          else
            "#{expr} IS NULL"
          end
        end

        def self.from_sql(value)
          case value
          when /^([^,]+),(.+)$/ then new($1, $2)
          when /^([^,]+),$/     then new($1, nil)
          when /^,(.+)$/        then new(nil, $1)
          when ',', nil         then new(nil, nil)
          else
            raise "Unexpected SQL bin format #{value}"
          end
        end

        def self.from_hash(h)
          # Returns either a bin or nil, depending on whether
          # the input is valid.
          return new(nil, nil) if h.nil?
          return unless h.is_a?(Hash)
          min, max = h.symbolize_keys.values_at(:min, :max)
          return if min.blank? && max.blank?
          new(min.presence, max.presence)
        end

        def as_json(*)
          return @as_json if instance_variable_defined?(:@as_json)
          @as_json = if min && max
            { min: min, max: max }
          elsif min
            { min: min }
          elsif max
            { max: max }
          else
            nil
          end
        end

        def [](key)
          return min if key.to_s == 'min'
          return max if key.to_s == 'max'
        end

        def has_key?(key)
          key.to_s == 'min' || key.to_s == 'max'
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
      end
    end
  end
end
