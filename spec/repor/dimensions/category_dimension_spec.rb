require 'spec_helper'

describe Repor::Dimensions::CategoryDimension do
  def author_dimension(report)
    described_class.new(:author, report, expression: 'authors.name', relation: ->(r) { r.joins(
      "LEFT OUTER JOIN authors ON authors.id = posts.author_id") })
  end

  describe '#filter' do
    it 'filters to rows matching at least one value' do
      p1 = create(:post, author: 'Alice')
      p2 = create(:post, author: 'Bob')
      p3 = create(:post, author: nil)

      def filter_by(author_values)
        report = OpenStruct.new(
          table_name: 'posts',
          params: { dimensions: { author: { only: author_values } } }
        )
        dimension = author_dimension(report)
        dimension.filter(dimension.relate(Post))
      end

      expect(filter_by(['Alice'])).to eq [p1]
      expect(filter_by([nil])).to eq [p3]
      expect(filter_by(['Alice', nil])).to eq [p1, p3]
      expect(filter_by(['Alice', 'Bob'])).to eq [p1, p2]
      expect(filter_by([])).to eq []
    end
  end

  describe '#group' do
    it 'groups the relation by the exact value of the SQL expression' do
      p1 = create(:post, author: 'Alice')
      p2 = create(:post, author: 'Alice')
      p3 = create(:post, author: nil)
      p4 = create(:post, author: 'Bob')
      p5 = create(:post, author: 'Bob')
      p6 = create(:post, author: 'Bob')

      report = OpenStruct.new(table_name: 'posts', params: {})
      dimension = author_dimension(report)

      results = dimension.group(dimension.relate(Post)).select("COUNT(*) AS count").map do |r|
        r.attributes.values_at(dimension.send(:sql_value_name), 'count')
      end

      expect(results).to eq [[nil, 1], ['Alice', 2], ['Bob', 3]]
    end
  end

  describe '#group_values' do
    it 'echoes filter_values if filtering' do
      dimension = author_dimension(OpenStruct.new(params: {
        dimensions: { author: { only: ['foo', 'bar'] } }
      }))
      expect(dimension.group_values).to eq %w(foo bar)
    end
  end

  describe '#all_values' do
    it 'returns all values for the dimension in the data (sanitized)' do
      p1 = create(:post, author: 'Alice')
      p2 = create(:post, author: 'Bob')
      p3 = create(:post, author: nil)

      dimension_class = Class.new(described_class) do
        # Note: this is a bad example of sanitization. `sanitize` should return
        # a value suitable for passing right back into the dimension for
        # filtering. A real example of this might be an enum column, where
        # integer values map to strings, and you have mapping both in and out,
        # in which case you'd override both `filter_values` AND `sanitize`.
        def sanitize(value)
          if value.present?
            "#{value}, Esq."
          else
            "No Author"
          end
        end
      end

      report = OpenStruct.new(params: {}, base_relation: Post)

      dimension = dimension_class.new(:author, report, expression: 'authors.name', relation: ->(r) { r.joins(
        "LEFT OUTER JOIN authors ON authors.id = posts.author_id") })

      expect(dimension.all_values).to match_array [
        'No Author',
        'Bob, Esq.',
        'Alice, Esq.'
      ]
    end
  end
end
