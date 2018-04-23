require 'spec_helper'

describe Repor::Dimension::Bin::Table do
  let(:bin_set) { Repor::Dimension::Bin::Set }

  describe '#filter' do
    it 'ORs together predicates across bins' do
      table = described_class.new([
        bin_set.new(nil, nil),
        bin_set.new(0, nil),
        bin_set.new(nil, 10),
        bin_set.new(3, 5)
      ])

      sql = table.filter(Post, 'x').to_sql

      expect(sql).to include "WHERE (x IS NULL OR x >= 0 OR x < 10 OR (x >= 3 AND x < 5))"
    end
  end

  describe '#group' do
    it 'joins to a union of bin rows, then groups by the range' do
      table = described_class.new([
        bin_set.new(nil, nil),
        bin_set.new(0, nil),
        bin_set.new(nil, 10),
        bin_set.new(3, 5)
      ])

      sql = table.group(Post, 'likes', 'likes').to_sql

      expect(sql).to start_with "SELECT likes_bin_table.bin_text AS likes"

      if Repor.database_type == :mysql
        expect(sql).to include "SELECT NULL AS min, NULL AS max, ',' AS bin_text"
        expect(sql).to include "SELECT 0 AS min, NULL AS max, '0,' AS bin_text"
        expect(sql).to include "SELECT NULL AS min, 10 AS max, ',10' AS bin_text"
        expect(sql).to include "SELECT 3 AS min, 5 AS max, '3,5' AS bin_text"
      else
        expect(sql).to include "SELECT NULL AS min, NULL AS max, CAST(',' AS text) AS bin_text"
        expect(sql).to include "SELECT 0 AS min, NULL AS max, CAST('0,' AS text) AS bin_text"
        expect(sql).to include "SELECT NULL AS min, 10 AS max, CAST(',10' AS text) AS bin_text"
        expect(sql).to include "SELECT 3 AS min, 5 AS max, CAST('3,5' AS text) AS bin_text"
      end
    end
  end
end
