require 'csv'

module Repor
  module Serializers
    class CsvSerializer < TableSerializer
      def csv_text
        CSV.generate do |csv|
          csv << headers
          each_row { |row| csv << row }
        end
      end

      def save(filename = self.filename)
        File.open(filename, 'w') { |f| f.write data }
      end

      def filename
        "#{caption.parameterize}.csv"
      end
    end
  end
end
