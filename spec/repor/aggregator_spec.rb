require 'spec_helper'

describe Repor::Aggregators do
  let(:report_class) do
    Class.new(Repor::Report) do
      report_on :Post
      category_dimension :author, expression: 'authors.name', relation: ->(r) { r.joins(:author) }
      count_aggregator :count
      sum_aggregator :total_likes, expression: 'posts.likes'
      avg_aggregator :mean_likes, expression: 'posts.likes'
      min_aggregator :min_likes, expression: 'posts.likes'
      max_aggregator :max_likes, expression: 'posts.likes'
      array_aggregator :post_ids, expression: 'posts.id'
    end
  end

  before do
    @p1 = create(:post, likes: 3, author: 'Alice')
    @p2 = create(:post, likes: 2, author: 'Alice')
    @p3 = create(:post, likes: 4, author: 'Bob')
    @p4 = create(:post, likes: 1, author: 'Bob')
    @p5 = create(:post, likes: 5, author: 'Bob')
    @p6 = create(:post, likes: 10, author: 'Chester')
  end

  def data_for(aggregator_name)
    report = report_class.new(aggregator: aggregator_name, groupers: [:author])
    report.raw_data
  end

  specify 'array' do
    if Repor.database_type == :postgres
      expect(data_for(:post_ids)).to eq(
        %w(Alice) => [@p1.id, @p2.id],
        %w(Bob) => [@p3.id, @p4.id, @p5.id],
        %w(Chester) => [@p6.id]
      )
    else
      expect { data_for(:post_ids) }.to raise_error(Repor::InvalidParamsError)
    end
  end

  specify 'max' do
    expect(data_for(:max_likes)).to eq %w(Alice) => 3, %w(Bob) => 5, %w(Chester) => 10
  end

  specify 'min' do
    expect(data_for(:min_likes)).to eq %w(Alice) => 2, %w(Bob) => 1, %w(Chester) => 10
  end

  specify 'avg' do
    d = data_for(:mean_likes)
    expect(d[%w(Alice)]).to eq 2.5
    expect(d[%w(Bob)].round(2)).to eq 3.33
    expect(d[%w(Chester)]).to eq 10
  end

  specify 'sum' do
    expect(data_for(:total_likes)).to eq %w(Alice) => 5, %w(Bob) => 10, %w(Chester) => 10
  end

  specify 'count' do
    expect(data_for(:count)).to eq %w(Alice) => 2, %w(Bob) => 3, %w(Chester) => 1
  end
end
