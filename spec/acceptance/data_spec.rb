require 'spec_helper'

describe 'more complicated case' do
  let(:report_class) do
    Class.new(Repor::Report) do
      report_on :Post

      time_dimension :created_at
      number_dimension :likes
      category_dimension :author, expression: 'authors.name', relation: ->(r) {
        r.joins('LEFT OUTER JOIN authors ON authors.id = posts.author_id')
      }

      count_aggregator :count
      sum_aggregator :total_likes, expression: 'posts.likes'
      avg_aggregator :mean_likes, expression: 'posts.likes'
      min_aggregator :min_likes, expression: 'posts.likes'
      max_aggregator :max_likes, expression: 'posts.likes'
    end
  end

  def data_by(groupers, g_params = nil)
    groupers = Array.wrap(groupers)
    dimension_params = {}
    if g_params
      g_params = Array.wrap(g_params)
      groupers.zip(g_params).each do |grouper, params|
        dimension_params[grouper] = params
      end
    end

    report = report_class.new(groupers: groupers, dimensions: dimension_params)
    report.data
  end

  def expect_equal(h1, h2)
    expect(JSON.parse(h1.to_json)).to eq JSON.parse(h2.to_json)
  end

  before do
    @joyce = create(:author, name: 'James Joyce')
    @woolf = create(:author, name: 'Virginia Woolf')

    @oct1 = Time.zone.parse('2015-10-01')
    @nov1 = Time.zone.parse('2015-11-01')
    @dec1 = Time.zone.parse('2015-12-01')
    @oct = { min: @oct1, max: @nov1 }
    @nov = { min: @nov1, max: @dec1 }

    @p1 = create(:post, author: @joyce.name, created_at: @oct1, likes: 1)
    @p2 = create(:post, author: @joyce.name, created_at: @oct1, likes: 2)
    @p3 = create(:post, author: @joyce.name, created_at: @nov1, likes: 1)
    @p4 = create(:post, author: @joyce.name, likes: 3).tap do |p|
      p.update!(created_at: nil)
    end

    @p5 = create(:post, author: @woolf.name, created_at: @oct1, likes: 2)
    @p6 = create(:post, author: @woolf.name, created_at: @nov1, likes: 3)
    @p7 = create(:post, author: @woolf.name, likes: 3).tap do |p|
      p.update!(created_at: nil)
    end

    @p9 = create(:post, author: nil, created_at: @oct1, likes: 2)
    @p10 = create(:post, author: nil, created_at: @nov1, likes: 3)
  end

  specify 'basic grouping, 1 grouper, no filters' do
    expect_equal data_by(:author), [
      { key: nil, value: 2 },
      { key: 'James Joyce', value: 4 },
      { key: 'Virginia Woolf', value: 3 }
    ]

    expect_equal data_by(:created_at, bin_width: '1 month'), [
      { key: nil, value: 2 },
      { key: @oct, value: 4 },
      { key: @nov, value: 3 }
    ]

    expect_equal data_by(:likes, bin_width: 1), [
      { key: { min: 1, max: 2 }, value: 2 },
      { key: { min: 2, max: 3 }, value: 3 },
      { key: { min: 3, max: 4 }, value: 4 }
    ]
  end

  specify 'basic grouping, >=2 groupers, no filters' do
    expect_equal data_by([:created_at, :author], bin_width: { months: 1 }), [
      { key: nil, values: [
        { key: nil,  value: 0 },
        { key: @oct, value: 1 },
        { key: @nov, value: 1 }]},
      { key: 'James Joyce', values: [
        { key: nil,  value: 1 },
        { key: @oct, value: 2 },
        { key: @nov, value: 1 }]},
      { key: 'Virginia Woolf', values: [
        { key: nil,  value: 1 },
        { key: @oct, value: 1 },
        { key: @nov, value: 1 }]}]
  end

  specify 'sorting with nulls (1 grouper)' do
    expect_equal data_by(:author, sort_desc: true), [
      { key: 'Virginia Woolf', value: 3 },
      { key: 'James Joyce', value: 4 },
      { key: nil, value: 2 }
    ]

    expect_equal data_by(:created_at, bin_width: '1 month', sort_desc: true), [
      { key: @nov, value: 3 },
      { key: @oct, value: 4 },
      { key: nil, value: 2 }
    ]

    if Repor.database_type == :postgres
      expect_equal data_by(:author, nulls_last: true), [
        { key: 'James Joyce', value: 4 },
        { key: 'Virginia Woolf', value: 3 },
        { key: nil, value: 2 }
      ]

      expect_equal data_by(:author, sort_desc: true, nulls_last: true), [
        { key: nil, value: 2 },
        { key: 'Virginia Woolf', value: 3 },
        { key: 'James Joyce', value: 4 }
      ]

      expect_equal data_by(:created_at, bin_width: '1 month', nulls_last: true), [
        { key: @oct, value: 4 },
        { key: @nov, value: 3 },
        { key: nil, value: 2 }
      ]

      expect_equal data_by(:created_at, bin_width: '1 month', sort_desc: true, nulls_last: true), [
        { key: nil, value: 2 },
        { key: @nov, value: 3 },
        { key: @oct, value: 4 }
      ]
    end
  end
end
