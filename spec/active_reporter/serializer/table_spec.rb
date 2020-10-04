require 'spec_helper'

describe ActiveReporter::Serializer::Table do
  let(:report_model) do
    Class.new(ActiveReporter::Report) do
      report_on :Post
      number_dimension :likes
      time_dimension :created_at
      category_dimension :title
      count_aggregator :post_count
    end
  end

  let(:report) do
    report_model.new(
      aggregators: :post_count,
      groupers: %i[created_at likes title],
      dimensions: {
        created_at: { bin_width: '1 day' },
        likes: { bin_width: 1 }
      }
    )
  end

  let(:table) do
    ActiveReporter::Serializer::Table.new(report)
  end

  before do
    create(:post, created_at: '2016-01-01', likes: 2, title: 'A')
    create(:post, created_at: '2016-01-01', likes: 2, title: 'A')
    create(:post, created_at: '2016-01-01', likes: 1, title: 'B')
    create(:post, created_at: '2016-01-02', likes: 1, title: 'A')
  end

  describe '#headers' do
    it 'is a formatted list of groupers and the aggregator' do
      expect(table.headers).to eq ['Created at', 'Likes', 'Title', 'Post count']
    end
  end

  describe '#caption' do
    it 'is a summary of the axes and the total record count' do
      expect(table.caption).to eq 'Post count by Created at, Likes, and Title for 4 Posts'
    end
  end

  describe '#each_row' do
    it 'iterates through arrays of formatted grouper values and the aggregator value' do
      expect(table.each_row.to_a).to eq [
        ['2016-01-01', '[1.0, 2.0)', 'A', 0],
        ['2016-01-01', '[1.0, 2.0)', 'B', 1],
        ['2016-01-01', '[2.0, 3.0)', 'A', 2],
        ['2016-01-01', '[2.0, 3.0)', 'B', 0],
        ['2016-01-02', '[1.0, 2.0)', 'A', 1],
        ['2016-01-02', '[1.0, 2.0)', 'B', 0],
        ['2016-01-02', '[2.0, 3.0)', 'A', 0],
        ['2016-01-02', '[2.0, 3.0)', 'B', 0]
      ]
    end
  end
end
