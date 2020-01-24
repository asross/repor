require 'spec_helper'

describe Repor::Aggregator do
  let(:report_model) do
    Class.new(Repor::Report) do
      report_on :Post
      category_dimension :author, expression: 'authors.name', relation: ->(r) { r.left_outer_joins(:author) }
      count_aggregator :count
      sum_aggregator :total_likes, expression: 'posts.likes'
      average_aggregator :mean_likes, expression: 'posts.likes'
      min_aggregator :min_likes, expression: 'posts.likes'
      max_aggregator :max_likes, expression: 'posts.likes'
      array_aggregator :post_ids, expression: 'posts.id'
    end
  end

  let(:report) { report_model.new(aggregators: aggregators, groupers: [:author]) }

  let!(:post_1) { create(:post, likes: 3, author: 'Alice') }
  let!(:post_2) { create(:post, likes: 2, author: 'Alice') }
  let!(:post_3) { create(:post, likes: 4, author: 'Bob') }
  let!(:post_4) { create(:post, likes: 1, author: 'Bob') }
  let!(:post_5) { create(:post, likes: 5, author: 'Bob') }
  let!(:post_6) { create(:post, likes: 10, author: 'Chester') }

  context 'aggregating post_ids' do
    let(:aggregators) { :post_ids }

    it 'should return post_ids values' do
      if Repor.database_type == :postgres
        expect(report.raw_data).to eq({
          ['Alice', 'post_ids'] => [post_1.id, post_2.id],
          ['Bob', 'post_ids'] => [post_3.id, post_4.id, post_5.id],
          ['Chester', 'post_ids'] => [post_6.id],
        })
      else
        expect { data_for(:post_ids) }.to raise_error(Repor::InvalidParamsError)
      end
    end
  end

  context 'aggregating max_likes' do
    let(:aggregators) { :max_likes }

    it 'should return max_likes values' do
      expect(report.raw_data).to eq({
        ['Alice', 'max_likes'] => 3,
        ['Bob', 'max_likes'] => 5,
        ['Chester', 'max_likes'] => 10,
      })
    end
  end

  context 'aggregating min_likes' do
    let(:aggregators) { :min_likes }

    it 'should return min_likes values' do
      expect(report.raw_data).to eq({
        ['Alice', 'min_likes'] => 2,
        ['Bob', 'min_likes'] => 1,
        ['Chester', 'min_likes'] => 10
      })
    end
  end

  context 'aggregating mean_likes' do
    let(:aggregators) { :mean_likes }

    it 'should return mean_likes values' do
      expect(report.raw_data.collect{ |k,v| [k, v.round(2)] }.to_h).to eq({
        ['Alice', 'mean_likes'] => 2.50,
        ['Bob', 'mean_likes'] => 3.33,
        ['Chester', 'mean_likes'] => 10.00,
      })
    end
  end

  context 'aggregating total_likes' do
    let(:aggregators) { :total_likes }

    it 'should return total_likes values' do
      expect(report.raw_data).to eq({
        ['Alice', 'total_likes'] => 5,
        ['Bob', 'total_likes'] => 10,
        ['Chester', 'total_likes'] => 10
      })
    end
  end

  context 'aggregating count' do
    let(:aggregators) { :count }

    it 'should return count values' do
      expect(report.raw_data).to eq({
        ['Alice', 'count'] => 2,
        ['Bob', 'count'] => 3,
        ['Chester', 'count'] => 1
      })
    end
  end
end
