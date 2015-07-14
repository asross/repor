module Repor
  class HistTable
    attr_reader :min, :max, :bin_size

    def initialize(bin_size, min, max)
      @min = min
      @max = max
      @bin_size = bin_size
    end

    def rows
      @rows ||= begin
        n1 = min.to_f
        result = []
        until n1 > max
          n2 = n1 + bin_size
          result << (n1..n2)
          n1 = n2
        end
        result
      end
    end

    def to_sql
      rows.map { |r| "SELECT #{sqlize_float(r.min)} AS min, #{sqlize_float(r.max)} AS max" }.join(' UNION ')
    end

    def sql_result
      @sql_result ||= ActiveRecord::Base.connection.execute(to_sql)
    end

    def sqlize_float(number)
      nb = ActiveRecord::Base.sanitize(number)
      case ActiveRecord::Base.connection.class.to_s.demodulize
      when "SQLite3Adapter", "PostgreSQLAdapter"
        "CAST(#{nb} AS float)"
      when "MysqlAdapter", "Mysql2Adapter"
        "CAST(#{nb} AS decimal)"
      else
        raise NotImplementedError, "No float handling yet for #{ActiveRecord::Base.connection.class}"
      end
    end
  end
end
