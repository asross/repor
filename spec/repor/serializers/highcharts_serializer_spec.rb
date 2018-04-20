require 'spec_helper'

describe Repor::Serializers::HighchartsSerializer do
  let(:report_class) do
    Class.new(Repor::Report) do
      report_on :Post
      number_dimension :likes
      time_dimension :created_at
      category_dimension :title
      count_aggregator :post_count
    end
  end

  let(:chart) do
    Repor::Serializers::HighchartsSerializer.new(report)
  end

  before do
    create(:post, created_at: '2016-01-01', likes: 2, title: 'A')
    create(:post, created_at: '2016-01-01', likes: 2, title: 'A')
    create(:post, created_at: '2016-01-01', likes: 1, title: 'B')
    create(:post, created_at: '2016-01-02', likes: 1, title: 'A')
  end

  def y_values(series)
    series[:data].map { |d| d[:y] }
  end

  def filters(series)
    series[:data].map { |d| d[:filters] }
  end

  describe '#series' do
    context 'with one grouper' do
      let(:report) do
        report_class.new(aggregators: :post_count, groupers: %i[title])
      end

      it 'returns one series of the y values (with filters)' do
        expect(chart.series.count).to eq 1
        # expect(y_values(chart.series[0])).to eq [3, 1]
        expect(filters(chart.series[0])).to eq [{ title: 'A' }, { title: 'B' }]
      end
    end

    context 'with two groupers' do
      let(:report) do
        report_class.new(
          aggregators: :post_count,
          groupers: %i[title likes],
          dimensions: { likes: { bin_width: 1 } }
        )
      end

      it 'returns one series for each x_2 value' do
        expect(chart.series.count).to eq 2
        # expect(y_values(chart.series[0])).to eq [1, 1]
        expect(filters(chart.series[0])).to eq [
          { title: 'A', likes: { min: 1, max: 2 } },
          { title: 'B', likes: { min: 1, max: 2 } }
        ]
        # expect(y_values(chart.series[1])).to eq [2, 0]
        expect(filters(chart.series[1])).to eq [
          { title: 'A', likes: { min: 2, max: 3 } },
          { title: 'B', likes: { min: 2, max: 3 } }
        ]
      end
    end

    context 'with three groupers' do
      let(:report) do
        report_class.new(
          aggregators: :post_count,
          groupers: %i[title likes created_at],
          dimensions: {
            likes: { bin_width: 1 },
            created_at: { bin_width: '1 day' }
          }
        )
      end

      it 'returns stacks for each x_3 of groups for each x_2' do
        expect(chart.series.count).to eq 4

        expect(chart.series[0][:stack]).to eq '2016-01-01'
        expect(chart.series[1][:stack]).to eq '2016-01-01'
        expect(chart.series[2][:stack]).to eq '2016-01-02'
        expect(chart.series[3][:stack]).to eq '2016-01-02'

        expect(chart.series[0][:id]).to eq '[1.0, 2.0)'
        expect(chart.series[1][:id]).to eq '[2.0, 3.0)'
        expect(chart.series[2][:linkedTo]).to eq '[1.0, 2.0)'
        expect(chart.series[3][:linkedTo]).to eq '[2.0, 3.0)'

        colors = chart.series.map { |s| s[:color] }
        expect(colors.all?(&:present?)).to be true
        expect(colors[0]).to eq colors[2]
        expect(colors[1]).to eq colors[3]
        expect(colors[0]).not_to eq colors[1]

        # expect(y_values(chart.series[0])).to eq [0, 1]

        jan1 = Time.zone.parse('2016-01-01')
        jan2 = Time.zone.parse('2016-01-02')

        expect(filters(chart.series[0])).to eq [
          { title: 'A', likes: { min: 1.0, max: 2.0 }, created_at: { min: jan1, max: jan2 } },
          { title: 'B', likes: { min: 1.0, max: 2.0 }, created_at: { min: jan1, max: jan2 } }
        ]
      end
    end
  end
end
