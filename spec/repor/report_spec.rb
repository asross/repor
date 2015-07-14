require 'spec_helper'

describe Repor do
  def report(x_axis, opts)
    CommentReport.new(opts.merge(x_axes: [x_axis]))
  end

  def report_by(x_axis, opts={})
    report(x_axis, opts).data
  end

  before do
    p1 = create(:post, title: 'P1', likes: 18, created_at: '2015-01-01')
    p2 = create(:post, title: 'P2', likes: 10, created_at: '2015-02-01')
    p3 = create(:post, title: 'P3', likes: 19, created_at: '2015-02-15')

    c11 = create(:comment, post: p1, author: 'Jim', created_at: '2015-01-02', likes: 5)
    c12 = create(:comment, post: p1, author: 'Bob', created_at: '2015-03-06', likes: 7)

    c21 = create(:comment, post: p2, author: 'Jim', created_at: '2015-03-10', likes: 10)
    c22 = create(:comment, post: p2, author: 'Sue', created_at: '2015-02-01', likes: 0)

    c31 = create(:comment, post: p3, author: 'Meg', created_at: '2015-02-11', likes: 6)
    c32 = create(:comment, post: p3, author: 'Meg', created_at: '2015-03-01', likes: 3)
  end

  specify 'class is initialized properly' do
    expect(CommentReport.klass).to eq Comment
    expect(CommentReport.dimensions).to match_array [:author, :post_title, :created_at, :post_created_at, :likes, :post_likes]
    expect(CommentReport.enum_dimensions).to match_array [:author, :post_title]
    expect(CommentReport.time_dimensions).to match_array [:created_at, :post_created_at]
    expect(CommentReport.hist_dimensions).to match_array [:likes, :post_likes]
    expect(Repor::Report.dimensions).to be_empty

    ims = CommentReport.instance_methods

    [:author, :post_title, :created_at, :post_created_at, :likes, :post_likes].each do |dimension|
      expect(ims).to include :"relation_for_#{dimension}"
      expect(ims).to include :"filtering_by_#{dimension}?"
      expect(ims).to include :"filtered_by_#{dimension}"
      expect(ims).to include :"grouped_by_#{dimension}"
    end
  end

  specify 'enumerated behavior' do
    expect(report_by(:author)).to eq(
      ['Jim'] => 2,
      ['Meg'] => 2,
      ['Bob'] => 1,
      ['Sue'] => 1
    )

    expect(report_by(:author, author_values: ['Jim', 'Sue'])).to eq(
      ['Jim'] => 2,
      ['Sue'] => 1
    )

    expect(report_by(:post_title)).to eq(
      ['P1'] => 2,
      ['P2'] => 2,
      ['P3'] => 2
    )

    expect(report_by(:post_title, post_title_values: ['P1', 'P2'])).to eq(
      ['P1'] => 2,
      ['P2'] => 2
    )

    expect(report_by(:post_title, post_title_values: ['P1', 'P2'], author_values: 'Jim')).to eq(
      ['P1'] => 1,
      ['P2'] => 1
    )

    # forgive empty strings
    expect(report_by(:post_title, post_title_values: [''], author_values: '')).to eq(
      ['P1'] => 2,
      ['P2'] => 2,
      ['P3'] => 2
    )
  end

  specify 'time behavior' do
    jan2015 = [Time.zone.parse('2015-01-01')]
    feb2015 = [Time.zone.parse('2015-02-01')]
    mar2015 = [Time.zone.parse('2015-03-01')]

    expect(report_by(:created_at, created_at_time_step: 'month')).to eq(
      jan2015 => 1,
      feb2015 => 2,
      mar2015 => 3
    )

    expect(report_by(:created_at, created_at_time_step: 'month', min_created_at: Time.zone.parse('2015-02-01'))).to eq(
      feb2015 => 2,
      mar2015 => 3
    )

    expect(report_by(:created_at, created_at_time_step: 'month', min_created_at: '2015-02-01')).to eq(
      feb2015 => 2,
      mar2015 => 3
    )

    expect(report_by(:created_at, created_at_time_step: 'month', min_created_at: '2015-02-01', max_created_at: '2015-02-28')).to eq(
      feb2015 => 2
    )

    expect(report_by(:post_created_at, post_created_at_time_step: 'month')).to eq(
      jan2015 => 2,
      feb2015 => 4
    )

    expect(report_by(:post_created_at, post_created_at_time_step: 'year')).to eq(
      jan2015 => 6
    )
  end

  specify 'hist behavior' do
    expect(report_by(:likes, likes_bin_size: 5)).to eq(
      [0.0] => 2,
      [5.0] => 3,
      [10.0] => 1
    )

    expect(report_by(:likes, likes_bin_size: 5, min_likes: 5)).to eq(
      [5.0] => 3,
      [10.0] => 1
    )

    expect(report_by(:post_likes, post_likes_bin_size: 5)).to eq(
      [10.0] => 2,
      [15.0] => 4
    )
  end

  specify 'multiple x axes and gap-filling' do
    report = CommentReport.new(x_axes: [:created_at, :author])

    expect(report.raw_data).to eq({
      ["2015-01-01 00:00:00", "Jim"]=>1,
      ["2015-02-01 00:00:00", "Meg"]=>1,
      ["2015-02-01 00:00:00", "Sue"]=>1,
      ["2015-03-01 00:00:00", "Bob"]=>1,
      ["2015-03-01 00:00:00", "Jim"]=>1,
      ["2015-03-01 00:00:00", "Meg"]=>1
    })

    report = CommentReport.new(x_axes: [:post_created_at, :likes, :author], post_created_at_time_step: 'month', likes_bin_size: 7.5)

    expect(report.raw_data).to eq({
      ["2015-01-01 00:00:00", 0.0, "Bob"]=>1,
      ["2015-01-01 00:00:00", 0.0, "Jim"]=>1,
      ["2015-02-01 00:00:00", 0.0, "Meg"]=>2,
      ["2015-02-01 00:00:00", 0.0, "Sue"]=>1,
      ["2015-02-01 00:00:00", 7.5, "Jim"]=>1
    })

    jan2015 = Time.zone.parse('2015-01-01')
    feb2015 = Time.zone.parse('2015-02-01')

    expect(report.data).to eq({
      [jan2015, 0.0, "Bob"]=>1,
      [jan2015, 0.0, "Jim"]=>1,
      [jan2015, 0.0, "Meg"]=>0,
      [jan2015, 0.0, "Sue"]=>0,
      [jan2015, 7.5, "Bob"]=>0,
      [jan2015, 7.5, "Jim"]=>0,
      [jan2015, 7.5, "Meg"]=>0,
      [jan2015, 7.5, "Sue"]=>0,
      [feb2015, 0.0, "Bob"]=>0,
      [feb2015, 0.0, "Jim"]=>0,
      [feb2015, 0.0, "Meg"]=>2,
      [feb2015, 0.0, "Sue"]=>1,
      [feb2015, 7.5, "Bob"]=>0,
      [feb2015, 7.5, "Jim"]=>1,
      [feb2015, 7.5, "Meg"]=>0,
      [feb2015, 7.5, "Sue"]=>0
    })
  end
end
