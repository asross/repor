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

  let(:groupers) { nil }
  let(:aggregators) { nil }
  let(:dimensions) { nil }
  let(:report) { report_class.new({groupers: groupers, aggregators: aggregators, dimensions: dimensions}.compact) }

  describe '.autoreport_on' do
    let(:report_class) { Class.new(Repor::Report) { autoreport_on :Post } }

    it 'infers dimensions from columns' do
      expect(report_class.dimensions.keys).to match_array %i[created_at updated_at title author likes]
    end

    it "should properly store created_at dimension class" do
      expect(report_class.dimensions[:created_at][:axis_class]).to eq Repor::Dimensions::TimeDimension
    end

    it "should properly store updated_at dimension class" do
      expect(report_class.dimensions[:updated_at][:axis_class]).to eq Repor::Dimensions::TimeDimension
    end

    it "should properly store likes dimension class" do
      expect(report_class.dimensions[:likes][:axis_class]).to eq Repor::Dimensions::NumberDimension
    end

    it "should properly store title dimension class" do
      expect(report_class.dimensions[:title][:axis_class]).to eq Repor::Dimensions::CategoryDimension
    end

    it "should properly store author dimension class" do
      expect(report_class.dimensions[:author][:axis_class]).to eq Repor::Dimensions::CategoryDimension
    end

    it 'should properly store author expression' do
      expect(report_class.dimensions[:author][:opts][:expression]).to eq 'authors.name'
    end
  end

  describe 'data access' do
    let(:groupers) { %w(author created_at) }
    let(:dimensions) { { created_at: { bin_width: { months: 1 } } } }
    let(:jan) { { min: Time.zone.parse('2016-01-01'), max: Time.zone.parse('2016-02-01') } }
    let(:feb) { { min: Time.zone.parse('2016-02-01'), max: Time.zone.parse('2016-03-01') } }
    let(:mar) { { min: Time.zone.parse('2016-03-01'), max: Time.zone.parse('2016-04-01') } }

    before(:each) do
      create(:post, author: 'Timmy', created_at: '2016-01-01')
      create(:post, author: 'Timmy', created_at: '2016-01-12')
      create(:post, author: 'Tammy', created_at: '2016-01-15')
      create(:post, author: 'Tammy', created_at: '2016-03-01')
    end

    it 'should return raw_data' do
      expect(report.raw_data).to eq(
        ['Tammy', jan, 'count'] => 1,
        ['Tammy', jan, 'likes'] => 0,
        ['Tammy', mar, 'count'] => 1,
        ['Tammy', mar, 'likes'] => 0,
        ['Timmy', jan, 'count'] => 2,
        ['Timmy', jan, 'likes'] => 0,
      )
    end

    it 'should return flat_data' do
      expect(report.flat_data).to eq(
        ['Tammy', jan, 'count'] => 1,
        ['Tammy', jan, 'likes'] => 0,
        ['Tammy', feb, 'count'] => 0,
        ['Tammy', feb, 'likes'] => 0,
        ['Tammy', mar, 'count'] => 1,
        ['Tammy', mar, 'likes'] => 0,
        ['Timmy', jan, 'count'] => 2,
        ['Timmy', jan, 'likes'] => 0,
        ['Timmy', feb, 'count'] => 0,
        ['Timmy', feb, 'likes'] => 0,
        ['Timmy', mar, 'count'] => 0,
        ['Timmy', mar, 'likes'] => 0,
      )
    end

    it 'should return nested_data' do
      expect(report.nested_data).to eq [
        { key: jan, values: [
          { key: 'Tammy', values: [{ key: 'count', value: 1 }, { key: 'likes', value: 0 }] },
          { key: 'Timmy', values: [{ key: 'count', value: 2 }, { key: 'likes', value: 0 }] }
        ] },
        { key: feb, values: [
          { key: 'Tammy', values: [{ key: 'count', value: 0 }, { key: 'likes', value: 0 }] },
          { key: 'Timmy', values: [{ key: 'count', value: 0 }, { key: 'likes', value: 0 }] }
        ] },
        { key: mar, values: [
          { key: 'Tammy', values: [{ key: 'count', value: 1 }, { key: 'likes', value: 0 }] },
          { key: 'Timmy', values: [{ key: 'count', value: 0 }, { key: 'likes', value: 0 }] }
        ] }
      ]
    end
  end

  describe '#dimensions' do
    it 'is a curried hash' do
      expect(report_class.dimensions.keys).to eq [:likes, :author, :created_at]
      expect(report.dimensions.keys).to eq [:likes, :author, :created_at]
      expect(report.dimensions[:likes]).to be_a Repor::Dimensions::NumberDimension
      expect(report.dimensions[:author]).to be_a Repor::Dimensions::CategoryDimension
      expect(report.dimensions[:created_at]).to be_a Repor::Dimensions::TimeDimension
    end
  end

  describe '#params' do
    let(:post1) { create(:post, author: 'Phil') }
    let(:post2) { create(:post, author: 'Phyllis') }

    context 'where author dimension only allows empty string' do
      let(:report) { report_class.new(dimensions: { author: { only: '' } }) }

      it 'strips empty string but preserves nil by default' do
        expect(report.params).to be_blank
        expect(report.dimensions[:author].filter_values).to be_blank
        expect(report.records).to eq [post1, post2]
      end
    end

    context 'where author dimension only allows array of empty string' do
      let(:report) { report_class.new(dimensions: { author: { only: [''] } }) }

      it 'strips empty string but preserves nil by default' do
        expect(report.params).to be_blank
        expect(report.dimensions[:author].filter_values).to be_blank
        expect(report.records).to eq [post1, post2]  
      end
    end

    context 'where author dimension only allows empty string or Phil' do
      let(:report) { report_class.new(dimensions: { author: { only: ['', 'Phil'] } }) }

      it 'strips empty string but preserves nil by default' do
        expect(report.params).to be_present
        expect(report.dimensions[:author].filter_values).to eq ['Phil']
        expect(report.records).to eq [post1]
      end
    end

    context 'where author dimension strips blank values and only allows empty string' do
      let(:report) { report_class.new(strip_blanks: false, dimensions: { author: { only: '' } }) }

      it 'strips empty string but preserves nil by default' do
        expect(report.params).to be_present
        expect(report.dimensions[:author].filter_values).to eq ['']
        expect(report.records).to eq []
      end
    end

    context 'where author dimension only allows nil' do
      let(:report) { report_class.new(dimensions: { author: { only: nil } }) }

      it 'strips empty string but preserves nil by default' do
        expect(report.params).to be_present
        expect(report.dimensions[:author].filter_values).to eq [nil]
        expect(report.records).to eq []
      end
    end
  end

  describe '#aggregators' do
    it 'is a curried hash' do
      expect(report_class.aggregators.keys).to eq [:count, :likes]
      expect(report.aggregators.keys).to eq [:count, :likes]
      expect(report.aggregators[:count]).to be_a Repor::Aggregator::Count
      expect(report.aggregators[:likes]).to be_a Repor::Aggregator::Sum
    end
  end

  describe '#groupers' do
    it 'defaults to the first' do
      expect(report.groupers).to eq [report.dimensions[:likes]]
    end

    context 'with created_at group' do
      let(:groupers) { 'created_at' }

      it 'can be set' do
        expect(report.groupers).to eq [report.dimensions[:created_at]]
      end
    end

    context 'with created_at and author groups' do
      let(:groupers) { %w(created_at author) }

      it 'can be set' do
        expect(report.groupers).to eq [report.dimensions[:created_at], report.dimensions[:author]]
      end
    end

    context 'with invalid group' do
      let(:groupers) { %w(chickens) }

      it 'should raise an exception' do
        expect { report }.to raise_error(Repor::InvalidParamsError)
      end
    end

    context 'on a report class with no dimensions declared' do
      let(:report_class) do
        Class.new(Repor::Report) do
          report_on :Post
          count_aggregator :count
        end
      end

      specify 'there must be at least one defined' do
        expect { report }.to raise_error Regexp.new('doesn\'t have any dimensions declared')
      end
    end
  end

  describe '#aggregators' do
    context 'where the report aggregators are set' do
      let(:aggregators) { 'likes' }

      it 'returns the set aggregators' do
        expect(report.aggregators.values).to contain_exactly report.aggregators[:likes]
      end
    end

    context 'where the report aggregators include an invalid value' do
      let(:aggregators) { 'chicken' }

      it 'should raise an exception' do
        expect { report }.to raise_error(Repor::InvalidParamsError)
      end
    end

    context 'on a report class with no dimensions declared' do
      let(:report_class) do
        Class.new(Repor::Report) do
          report_on :Post
          time_dimension :created_at
        end
      end

      specify 'there must be at least one defined' do
        expect { report }.to raise_error Regexp.new('doesn\'t have any aggregators declared')
      end
    end
  end

  describe '#total_data' do
    let(:report_class) do
      Class.new(Repor::Report) do
        report_on :Post
        count_aggregator :count
        sum_aggregator :likes
        max_aggregator :max_likes, expression: :likes
        number_dimension :likes
        category_dimension :author, expression: 'authors.name', relation: ->(r) { r.joins(:author) }
        time_dimension :created_at

        category_dimension :totals, expression: "'totals'"
      end
    end

    let(:groupers) { %w(author created_at) }
    let(:aggregators) { :likes }
    let(:dimensions) { { likes: { bin_width: 1 }, created_at: { bin_width: { months: 1 } } } }

    before(:each) do
      create(:post, author: 'Timmy', created_at: '2016-01-01', likes: 1)
      create(:post, author: 'Timmy', created_at: '2016-01-12', likes: 2)
      create(:post, author: 'Tammy', created_at: '2016-01-15', likes: 3)
      create(:post, author: 'Tammy', created_at: '2016-03-01', likes: 4)
      create(:post, author: 'Tammy', created_at: '2016-03-15', likes: 2)
    end

    it 'should let me test' do
      # puts report.raw_data.inspect
      # puts report.flat_data.inspect
      # puts report.data.inspect
      # puts report.totals.inspect
    end
  end
end
