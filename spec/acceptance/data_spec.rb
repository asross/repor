require 'spec_helper'

describe 'more complicated case' do
  let(:report_model) do
    Class.new(ActiveReporter::Report) do
      report_on :Post

      time_dimension :published_at
      number_dimension :likes
      category_dimension :author, model: :author, attribute: :name, relation: ->(r) { r.left_outer_joins(:author) }

      count_aggregator :count
      sum_aggregator :total_likes, attribute: :likes
      average_aggregator :mean_likes, attribute: :likes
      min_aggregator :min_likes, attribute: :likes
      max_aggregator :max_likes, attribute: :likes
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

    report = report_model.new(groupers: groupers, dimensions: dimension_params)
    report.data
  end

  def expect_equal(h1, h2)
    expect(JSON.parse(h1.to_json)).to eq JSON.parse(h2.to_json)
  end

  let(:joyce) { create(:author, name: 'James Joyce') }
  let(:woolf) { create(:author, name: 'Virginia Woolf') }

  let(:oct_1) { Time.zone.parse('2015-10-01') }
  let(:nov_1) { Time.zone.parse('2015-11-01') }
  let(:dec_1) { Time.zone.parse('2015-12-01') }

  let(:oct) { { min: oct_1, max: nov_1 } }
  let(:nov) { { min: nov_1, max: dec_1 } }

  let!(:post_1) { create(:post, author: joyce.name, published_at: oct_1, likes: 1) }
  let!(:post_2) { create(:post, author: joyce.name, published_at: oct_1, likes: 2) }
  let!(:post_3) { create(:post, author: joyce.name, published_at: nov_1, likes: 1) }
  let!(:post_4) { create(:post, author: joyce.name, likes: 3).tap { |p| p.update!(published_at: nil) } }

  let!(:post_5) { create(:post, author: woolf.name, published_at: oct_1, likes: 2) }
  let!(:post_6) { create(:post, author: woolf.name, published_at: nov_1, likes: 3) }
  let!(:post_7) { create(:post, author: woolf.name, likes: 3).tap { |p| p.update!(published_at: nil) } }

  let!(:post_8) { create(:post, author: nil, published_at: oct_1, likes: 2) }
  let!(:post_9) { create(:post, author: nil, published_at: nov_1, likes: 3) }

  specify 'basic grouping, 1 grouper, no filters' do
    expect_equal data_by(:author), [
      { key: nil, values: [
        { key: :count, value: 2 },
        { key: :total_likes, value: 5 },
        { key: :mean_likes, value: '2.5' },
        { key: :min_likes, value: 2 },
        { key: :max_likes, value: 3 }
      ] },
      { key: joyce.name, values: [
        { key: :count, value: 4 },
        { key: :total_likes, value: 7 },
        { key: :mean_likes, value: '1.75' },
        { key: :min_likes, value: 1 },
        { key: :max_likes, value: 3 }
      ] },
      { key: woolf.name, values: [
        { key: :count, value: 3 },
        { key: :total_likes, value: 8 },
        { key: :mean_likes, value: '2.6666666666666667' },
        { key: :min_likes, value: 2 },
        { key: :max_likes, value: 3 }
      ] }
    ]

    expect_equal data_by(:published_at, bin_width: '1 month'), [
      { key: nil, values: [
        { key: :count, value: 2 },
        { key: :total_likes, value: 6 },
        { key: :mean_likes, value: '3.0' },
        { key: :min_likes, value: 3 },
        { key: :max_likes, value: 3 }
      ] },
      { key: oct, values: [
        { key: :count, value: 4 },
        { key: :total_likes, value: 7 },
        { key: :mean_likes, value: '1.75' },
        { key: :min_likes, value: 1 },
        { key: :max_likes, value: 2 }
      ] },
      { key: nov, values: [
        { key: :count, value: 3 },
        { key: :total_likes, value: 7 },
        { key: :mean_likes, value: '2.3333333333333333' },
        { key: :min_likes, value: 1 },
        { key: :max_likes, value: 3 }
      ] }
    ]

    expect_equal data_by(:likes, bin_width: 1), [
      { key: { min: 1, max: 2 }, values: [
        { key: :count, value: 2 },
        { key: :total_likes, value: 2 },
        { key: :mean_likes, value: '1.0' },
        { key: :min_likes, value: 1 },
        { key: :max_likes, value: 1 }
      ] },
      { key: { min: 2, max: 3 }, values: [
        { key: :count, value: 3 },
        { key: :total_likes, value: 6 },
        { key: :mean_likes, value: '2.0' },
        { key: :min_likes, value: 2 },
        { key: :max_likes, value: 2 }
      ] },
      { key: { min: 3, max: 4 }, values: [
        { key: :count, value: 4 },
        { key: :total_likes, value: 12 },
        { key: :mean_likes, value: '3.0' },
        { key: :min_likes, value: 3 },
        { key: :max_likes, value: 3 }
      ] }
    ]
  end

  specify 'basic grouping, >=2 groupers, no filters' do
    expect_equal data_by([:published_at, :author], bin_width: { months: 1 }), [
      { key: nil, values: [
        { key: nil,  values: [
          { key: :count, value: 0 },
          { key: :total_likes, value: 0 },
          { key: :mean_likes, value: nil },
          { key: :min_likes, value: nil },
          { key: :max_likes, value: nil }
        ] },
        { key: oct, values: [
          { key: :count, value: 1 },
          { key: :total_likes, value: 2 },
          { key: :mean_likes, value: '2.0' },
          { key: :min_likes, value: 2 },
          { key: :max_likes, value: 2 }
        ] },
        { key: nov, values: [
          { key: :count, value: 1 },
          { key: :total_likes, value: 3 },
          { key: :mean_likes, value: '3.0' },
          { key: :min_likes, value: 3 },
          { key: :max_likes, value: 3 }
        ] }
      ] },
      { key: joyce.name, values: [
        { key: nil,  values: [
          { key: :count, value: 1 },
          { key: :total_likes, value: 3 },
          { key: :mean_likes, value: '3.0' },
          { key: :min_likes, value: 3 },
          { key: :max_likes, value: 3 }
        ] },
        { key: oct, values: [
          { key: :count, value: 2 },
          { key: :total_likes, value: 3 },
          { key: :mean_likes, value: '1.5' },
          { key: :min_likes, value: 1 },
          { key: :max_likes, value: 2 }
        ] },
        { key: nov, values: [
          { key: :count, value: 1 },
          { key: :total_likes, value: 1 },
          { key: :mean_likes, value: '1.0' },
          { key: :min_likes, value: 1 },
          { key: :max_likes, value: 1 }
        ] }
      ] },
      { key: woolf.name, values: [
        { key: nil,  values: [
          { key: :count, value: 1 },
          { key: :total_likes, value: 3 },
          { key: :mean_likes, value: '3.0' },
          { key: :min_likes, value: 3 },
          { key: :max_likes, value: 3 }
        ] },
        { key: oct, values: [
          { key: :count, value: 1 },
          { key: :total_likes, value: 2 },
          { key: :mean_likes, value: '2.0' },
          { key: :min_likes, value: 2 },
          { key: :max_likes, value: 2 }
        ] },
        { key: nov, values: [
          { key: :count, value: 1 },
          { key: :total_likes, value: 3 },
          { key: :mean_likes, value: '3.0' },
          { key: :min_likes, value: 3 },
          { key: :max_likes, value: 3 }
        ] }
      ] } 
    ]
  end

  specify 'sorting with nulls (1 grouper)' do
    expect_equal data_by(:author, sort_desc: true), [
      { key: woolf.name, values: [
        { key: :count, value: 3 },
        { key: :total_likes, value: 8 },
        { key: :mean_likes, value: '2.6666666666666667' },
        { key: :min_likes, value: 2 },
        { key: :max_likes, value: 3 }
      ] },
      { key: joyce.name, values: [
        { key: :count, value: 4 },
        { key: :total_likes, value: 7 },
        { key: :mean_likes, value: '1.75' },
        { key: :min_likes, value: 1 },
        { key: :max_likes, value: 3 }
      ] },
      { key: nil, values: [
        {key: :count, value: 2 },
        {key: :total_likes, value: 5 },
        {key: :mean_likes, value: '2.5' },
        {key: :min_likes, value: 2 },
        {key: :max_likes, value: 3 }
      ] }
    ]

    expect_equal data_by(:published_at, bin_width: '1 month', sort_desc: true), [
      { key: nov, values: [
        { key: :count, value: 3 },
        { key: :total_likes, value: 7 },
        { key: :mean_likes, value: '2.3333333333333333' },
        { key: :min_likes, value: 1 },
        { key: :max_likes, value: 3 }
      ] },
      { key: oct, values: [
        { key: :count, value: 4 },
        { key: :total_likes, value: 7 },
        { key: :mean_likes, value: '1.75' },
        { key: :min_likes, value: 1 },
        { key: :max_likes, value: 2 }
      ] },
      { key: nil, values: [
        { key: :count, value: 2 },
        { key: :total_likes, value: 6 },
        { key: :mean_likes, value: '3.0' },
        { key: :min_likes, value: 3 },
        { key: :max_likes, value: 3 }
      ] }
    ]

    if ActiveReporter.database_type == :postgres
      expect_equal data_by(:author, nulls_last: true), [
        { key: joyce.name, values: [
          { key: :count, value: 4 },
          { key: :total_likes, value: 7 },
          { key: :mean_likes, value: '1.75' },
          { key: :min_likes, value: 1 },
          { key: :max_likes, value: 3 }
        ] },
        { key: woolf.name, values: [
          { key: :count, value: 3 },
          { key: :total_likes, value: 8 },
          { key: :mean_likes, value: '2.6666666666666667' },
          { key: :min_likes, value: 2 },
          { key: :max_likes, value: 3 }
        ] },
        { key: nil, values: [
          { key: :count, value: 2 },
          { key: :total_likes, value: 5 },
          { key: :mean_likes, value: '2.5' },
          { key: :min_likes, value: 2 },
          { key: :max_likes, value: 3 }
        ] }
      ]

      expect_equal data_by(:author, sort_desc: true, nulls_last: true), [
        { key: nil, values: [
          { key: :count, value: 2 },
          { key: :total_likes, value: 5 },
          { key: :mean_likes, value: '2.5' },
          { key: :min_likes, value: 2 },
          { key: :max_likes, value: 3 }
        ] },
        { key: woolf.name, values: [
          { key: :count, value: 3 },
          { key: :total_likes, value: 8 },
          { key: :mean_likes, value: '2.6666666666666667' },
          { key: :min_likes, value: 2 },
          { key: :max_likes, value: 3 }
        ] },
        { key: joyce.name, values: [
          { key: :count, value: 4 },
          { key: :total_likes, value: 7 },
          { key: :mean_likes, value: '1.75' },
          { key: :min_likes, value: 1 },
          { key: :max_likes, value: 3 }
        ] }
      ]

      expect_equal data_by(:published_at, bin_width: '1 month', nulls_last: true), [
        { key: oct, values: [
          { key: :count, value: 4 },
          { key: :total_likes, value: 7 },
          { key: :mean_likes, value: '1.75' },
          { key: :min_likes, value: 1 },
          { key: :max_likes, value: 2 }
        ] },
        { key: nov, values: [
          { key: :count, value: 3 },
          { key: :total_likes, value: 7 },
          { key: :mean_likes, value: '2.3333333333333333' },
          { key: :min_likes, value: 1 },
          { key: :max_likes, value: 3 }
        ] },
        { key: nil, values: [
          { key: :count, value: 2 },
          { key: :total_likes, value: 6 },
          { key: :mean_likes, value: '3.0' },
          { key: :min_likes, value: 3 },
          { key: :max_likes, value: 3 }
        ] }
      ]

      expect_equal data_by(:published_at, bin_width: '1 month', sort_desc: true, nulls_last: true), [
        { key: nil, values: [
          { key: :count, value: 2 },
          { key: :total_likes, value: 6 },
          { key: :mean_likes, value: '3.0' },
          { key: :min_likes, value: 3 },
          { key: :max_likes, value: 3 }
        ] },
        { key: nov, values: [
          { key: :count, value: 3 },
          { key: :total_likes, value: 7 },
          { key: :mean_likes, value: '2.3333333333333333' },
          { key: :min_likes, value: 1 },
          { key: :max_likes, value: 3 }
        ] },
        { key: oct, values: [
          { key: :count, value: 4 },
          { key: :total_likes, value: 7 },
          { key: :mean_likes, value: '1.75' },
          { key: :min_likes, value: 1 },
          { key: :max_likes, value: 2 }
        ] }
      ]
    end
  end
end
