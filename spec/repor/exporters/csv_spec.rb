require 'spec_helper'

describe Repor::Exporters::CSV do
  def csv_for(x_axis, opts={})
    report = CommentReport.new(opts.reverse_merge(x_axes: [x_axis]))
    data = Repor::Exporters::CSV.new(report).csv
    CSV.parse(data, headers: true)
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

  specify 'it can dump data to a CSV with one grouping dimension' do
    csv = csv_for(:author)

    expect(csv.headers).to eq ['author', 'comment_count']
    expect(csv.entries.map(&:to_h)).to match_array([
      { 'author' => 'Jim', 'comment_count' => '2' },
      { 'author' => 'Meg', 'comment_count' => '2' },
      { 'author' => 'Bob', 'comment_count' => '1' },
      { 'author' => 'Sue', 'comment_count' => '1' }
    ])
  end

  specify 'it can handle multiple grouping dimensions' do
    csv = csv_for(nil, x_axes: [:author, :post_title])

    expect(csv.headers).to eq ['author', 'post_title', 'comment_count']
    expect(csv.entries.map(&:to_h)).to match_array([
      { 'author' => 'Bob', 'post_title' => 'P1', 'comment_count' => '1' },
      { 'author' => 'Bob', 'post_title' => 'P2', 'comment_count' => '0' },
      { 'author' => 'Bob', 'post_title' => 'P3', 'comment_count' => '0' },

      { 'author' => 'Jim', 'post_title' => 'P1', 'comment_count' => '1' },
      { 'author' => 'Jim', 'post_title' => 'P2', 'comment_count' => '1' },
      { 'author' => 'Jim', 'post_title' => 'P3', 'comment_count' => '0' },

      { 'author' => 'Meg', 'post_title' => 'P1', 'comment_count' => '0' },
      { 'author' => 'Meg', 'post_title' => 'P2', 'comment_count' => '0' },
      { 'author' => 'Meg', 'post_title' => 'P3', 'comment_count' => '2' },

      { 'author' => 'Sue', 'post_title' => 'P1', 'comment_count' => '0' },
      { 'author' => 'Sue', 'post_title' => 'P2', 'comment_count' => '1' },
      { 'author' => 'Sue', 'post_title' => 'P3', 'comment_count' => '0' }
    ])
  end
end
