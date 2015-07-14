module Repor
  class TimeTable
    attr_reader :min, :max, :time_step

    def initialize(time_step, min, max)
      @time_step = time_step
      @min = min
      @max = max
    end

    def rows
      @rows ||= begin
        t1 = min.send("beginning_of_#{time_step}")
        result = []
        until t1 > max.send("end_of_#{time_step}")
          t2 = t1.send("end_of_#{time_step}")
          result << (t1..t2)
          t1 = (t2 + 1.second).send("beginning_of_#{time_step}")
        end
        result
      end
    end

    def to_sql
      rows.map { |t| "SELECT #{sqlize_time(t.min)} AS min, #{sqlize_time(t.max)} AS max" }.join(' UNION ')
    end

    def sqlize_time(time)
      tm = ActiveRecord::Base.sanitize(time)
      case ActiveRecord::Base.connection.class.to_s.demodulize
      when "SQLite3Adapter"
        "DATETIME(#{tm})"
      when "PostgreSQLAdapter"
        "TIMESTAMP #{tm}"
      when "MysqlAdapter", "Mysql2Adapter"
        "CAST(#{tm} AS DATETIME)"
      else
        raise NotImplementedError, "No timestamp handling yet for #{ActiveRecord::Base.connection.class}"
      end
    end
  end
end
