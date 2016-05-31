require 'spec_helper'

describe Repor::Report do
  let(:report_class) do
    Class.new(Repor::Report) do
      report_on :Post
      count_aggregator :count
      sum_aggregator :likes
      number_dimension :likes
      category_dimension :author, expression: 'authors.name', relation: ->(r) { r.joins(:author) }
      time_dimension :created_at
    end
  end

  describe '.autoreport_on' do
    let(:report_class) do
      Class.new(Repor::Report) { autoreport_on :Post }
    end

    it 'infers dimensions from columns' do
      expect(report_class.dimensions.keys).to match_array %i[created_at updated_at title author likes]

      def expect_dim_type(type, name)
        expect(report_class.dimensions[name][:axis_class]).to eq type
      end

      expect_dim_type(Repor::Dimensions::TimeDimension, :created_at)
      expect_dim_type(Repor::Dimensions::TimeDimension, :updated_at)
      expect_dim_type(Repor::Dimensions::NumberDimension, :likes)
      expect_dim_type(Repor::Dimensions::CategoryDimension, :title)
      expect_dim_type(Repor::Dimensions::CategoryDimension, :author)
      expect(report_class.dimensions[:author][:opts][:expression]).to eq 'authors.name'
    end
  end

  describe 'data access' do
    it 'can be raw, flat, or nested' do
      create(:post, author: 'Timmy', created_at: '2016-01-01')
      create(:post, author: 'Timmy', created_at: '2016-01-12')
      create(:post, author: 'Tammy', created_at: '2016-01-15')
      create(:post, author: 'Tammy', created_at: '2016-03-01')

      report = report_class.new(
        groupers: %w(author created_at),
        dimensions: { created_at: { bin_width: { months: 1 } } }
      )

      jan = { min: Time.zone.parse('2016-01-01'), max: Time.zone.parse('2016-02-01') }
      feb = { min: Time.zone.parse('2016-02-01'), max: Time.zone.parse('2016-03-01') }
      mar = { min: Time.zone.parse('2016-03-01'), max: Time.zone.parse('2016-04-01') }

      expect(report.raw_data).to eq(
        ['Tammy', jan] => 1,
        ['Tammy', mar] => 1,
        ['Timmy', jan] => 2
      )

      expect(report.flat_data).to eq(
        ['Tammy', jan] => 1, ['Tammy', feb] => 0, ['Tammy', mar] => 1,
        ['Timmy', jan] => 2, ['Timmy', feb] => 0, ['Timmy', mar] => 0
      )

      expect(report.nested_data).to eq [
        { key: jan, values: [{ key: 'Tammy', value: 1 }, { key: 'Timmy', value: 2 }] },
        { key: feb, values: [{ key: 'Tammy', value: 0 }, { key: 'Timmy', value: 0 }] },
        { key: mar, values: [{ key: 'Tammy', value: 1 }, { key: 'Timmy', value: 0 }] }
      ]
    end
  end

  describe '#dimensions' do
    it 'is a curried hash' do
      expect(report_class.dimensions.keys).to eq [:likes, :author, :created_at]
      report = report_class.new
      expect(report.dimensions.keys).to eq [:likes, :author, :created_at]
      expect(report.dimensions[:likes]).to be_a Repor::Dimensions::NumberDimension
      expect(report.dimensions[:author]).to be_a Repor::Dimensions::CategoryDimension
      expect(report.dimensions[:created_at]).to be_a Repor::Dimensions::TimeDimension
    end
  end

  describe '#params' do
    it 'strips "" but preserves nil by default' do
      post1 = create(:post, author: 'Phil')
      post2 = create(:post, author: 'Phyllis')

      report = report_class.new(dimensions: { author: { only: '' } })

      expect(report.params).to be_blank
      expect(report.dimensions[:author].filter_values).to be_blank
      expect(report.records).to eq [post1, post2]

      report = report_class.new(dimensions: { author: { only: [''] } })

      expect(report.params).to be_blank
      expect(report.dimensions[:author].filter_values).to be_blank
      expect(report.records).to eq [post1, post2]

      report = report_class.new(dimensions: { author: { only: ['', 'Phil'] } })

      expect(report.params).to be_present
      expect(report.dimensions[:author].filter_values).to eq ['Phil']
      expect(report.records).to eq [post1]

      report = report_class.new(strip_blanks: false, dimensions: { author: { only: '' } })

      expect(report.params).to be_present
      expect(report.dimensions[:author].filter_values).to eq ['']
      expect(report.records).to eq []

      report = report_class.new(dimensions: { author: { only: nil } })

      expect(report.params).to be_present
      expect(report.dimensions[:author].filter_values).to eq [nil]
      expect(report.records).to eq []
    end
  end

  describe '#aggregators' do
    it 'is a curried hash' do
      expect(report_class.aggregators.keys).to eq [:count, :likes]
      report = report_class.new
      expect(report.aggregators.keys).to eq [:count, :likes]
      expect(report.aggregators[:count]).to be_a Repor::Aggregators::CountAggregator
      expect(report.aggregators[:likes]).to be_a Repor::Aggregators::SumAggregator
    end
  end

  describe '#groupers' do
    it 'defaults to the first' do
      report = report_class.new
      expect(report.groupers).to eq [report.dimensions[:likes]]
    end

    it 'can be set' do
      report = report_class.new(groupers: 'created_at')
      expect(report.groupers).to eq [report.dimensions[:created_at]]
      report = report_class.new(groupers: %w(created_at author))
      expect(report.groupers).to eq [report.dimensions[:created_at], report.dimensions[:author]]
    end

    it 'must be valid' do
      expect {
        report_class.new(groupers: %w(chickens))
      }.to raise_error(Repor::InvalidParamsError)
    end

    specify 'there must be at least one defined' do
      r = Class.new(Repor::Report) do
        report_on :Post
        count_aggregator :count
      end
      expect { r.new }.to raise_error /doesn't have any dimensions declared/
    end
  end

  describe '#aggregator' do
    it 'defaults to the first' do
      report = report_class.new
      expect(report.aggregator).to eq report.aggregators[:count]
    end

    it 'can be set' do
      report = report_class.new(aggregator: 'likes')
      expect(report.aggregator).to eq report.aggregators[:likes]
    end

    it 'must be valid' do
      expect {
        report_class.new(aggregator: 'chicken')
      }.to raise_error(Repor::InvalidParamsError)
    end

    specify 'there must be at least one defined' do
      r = Class.new(Repor::Report) do
        report_on :Post
        time_dimension :created_at
      end
      expect { r.new }.to raise_error /doesn't have any aggregators declared/
    end
  end
end
