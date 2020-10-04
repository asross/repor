require 'spec_helper'

describe ActiveReporter::Aggregator do
  let(:report_model) do
    Class.new(ActiveReporter::Report) do
      report_on :Post
      category_dimension :author, model: :author, attribute: :name, relation: ->(r) { r.left_outer_joins(:author) }
      enum_dimension :status, attribute: :status
      count_aggregator :count
      sum_aggregator :total_likes, attribute: :likes
      average_aggregator :mean_likes, attribute: :likes
      min_aggregator :min_likes, attribute: :likes
      max_aggregator :max_likes, attribute: :likes
      array_aggregator :post_ids, attribute: :id
    end
  end

  let(:report) { report_model.new(aggregators: aggregators, groupers: [:author, :status]) }

  let!(:post_1) { create(:post, likes: 3, author: 'Alice') }
  let!(:post_2) { create(:post, likes: 2, author: 'Alice') }
  let!(:post_3) { create(:post, likes: 4, author: 'Bob') }
  let!(:post_4) { create(:post, likes: 1, author: 'Bob') }
  let!(:post_5) { create(:post, likes: 5, author: 'Bob') }
  let!(:post_6) { create(:post, likes: 10, author: 'Chester') }

  context 'aggregating post_ids' do
    let(:aggregators) { :post_ids }

    it 'should return post_ids values' do
      if ActiveReporter.database_type == :postgres
        expect(report.raw_data).to eq({
          ['Alice', 'published', 'post_ids'] => [post_1.id, post_2.id],
          ['Bob', 'published', 'post_ids'] => [post_3.id, post_4.id, post_5.id],
          ['Chester', 'published', 'post_ids'] => [post_6.id],
        })
      else
        expect { report.raw_data }.to raise_error(ActiveReporter::InvalidParamsError)
      end
    end
  end

  context 'aggregating max_likes' do
    let(:aggregators) { :max_likes }

    it 'should return max_likes values' do
      expect(report.raw_data).to eq({
        ['Alice', 'published', 'max_likes'] => 3,
        ['Bob', 'published', 'max_likes'] => 5,
        ['Chester', 'published', 'max_likes'] => 10,
      })
    end
  end

  context 'aggregating min_likes' do
    let(:aggregators) { :min_likes }

    it 'should return min_likes values' do
      expect(report.raw_data).to eq({
        ['Alice', 'published', 'min_likes'] => 2,
        ['Bob', 'published', 'min_likes'] => 1,
        ['Chester', 'published', 'min_likes'] => 10
      })
    end
  end

  context 'aggregating mean_likes' do
    let(:aggregators) { :mean_likes }

    it 'should return mean_likes values' do
      expect(report.raw_data.collect{ |k,v| [k, v.round(2)] }.to_h).to eq({
        ['Alice', 'published', 'mean_likes'] => 2.50,
        ['Bob', 'published', 'mean_likes'] => 3.33,
        ['Chester', 'published', 'mean_likes'] => 10.00,
      })
    end
  end

  context 'aggregating total_likes' do
    let(:aggregators) { :total_likes }

    it 'should return total_likes values' do
      expect(report.raw_data).to eq({
        ['Alice', 'published', 'total_likes'] => 5,
        ['Bob', 'published', 'total_likes'] => 10,
        ['Chester', 'published', 'total_likes'] => 10
      })
    end
  end

  context 'aggregating count' do
    let(:aggregators) { :count }

    it 'should return count values' do
      expect(report.raw_data).to eq({
        ['Alice', 'published', 'count'] => 2,
        ['Bob', 'published', 'count'] => 3,
        ['Chester', 'published', 'count'] => 1
      })
    end
  end
end
