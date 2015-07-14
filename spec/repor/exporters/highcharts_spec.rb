require 'spec_helper'

describe Repor::Exporters::Highcharts do
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

  it 'computes data series and categories for one dimension' do
    exporter = Repor::Exporters::Highcharts.new(CommentReport.new(x_axis: 'author', y_axis: 'comment_count'))
    expect(exporter.categories).to eq ["Bob", "Jim", "Meg", "Sue"]
    expect(exporter.series).to eq([
      {
        :name=>"Comment count",
        :data=> [
          {:y=>1, :filters=>{:author_values=>"Bob"}},
          {:y=>2, :filters=>{:author_values=>"Jim"}},
          {:y=>2, :filters=>{:author_values=>"Meg"}},
          {:y=>1, :filters=>{:author_values=>"Sue"}}
        ]
      }
    ])
  end

  it 'can handle two dimensions (but no more)' do
    exporter = Repor::Exporters::Highcharts.new(CommentReport.new(x_axes: %w(author created_at), y_axis: 'comment_count'))
    expect(exporter.categories).to eq ["Bob", "Jim", "Meg", "Sue"]
    expect(exporter.series).to eq([
      {:name=>"2015-01-01 00:00:00 UTC",
       :data=>
       [{:y=>0, :filters=>{:author_values=>"Bob", :min_created_at=>Time.zone.parse('Thu, 01 Jan 2015 00:00:00 UTC +00:00'), :max_created_at=>Time.parse('Sat, 31 Jan 2015 23:59:59.999999999 UTC +00:00')}},
        {:y=>1, :filters=>{:author_values=>"Jim", :min_created_at=>Time.zone.parse('Thu, 01 Jan 2015 00:00:00 UTC +00:00'), :max_created_at=>Time.parse('Sat, 31 Jan 2015 23:59:59.999999999 UTC +00:00')}},
        {:y=>0, :filters=>{:author_values=>"Meg", :min_created_at=>Time.zone.parse('Thu, 01 Jan 2015 00:00:00 UTC +00:00'), :max_created_at=>Time.parse('Sat, 31 Jan 2015 23:59:59.999999999 UTC +00:00')}},
        {:y=>0, :filters=>{:author_values=>"Sue", :min_created_at=>Time.zone.parse('Thu, 01 Jan 2015 00:00:00 UTC +00:00'), :max_created_at=>Time.parse('Sat, 31 Jan 2015 23:59:59.999999999 UTC +00:00')}}]},
      {:name=>"2015-02-01 00:00:00 UTC",
       :data=>
       [{:y=>0, :filters=>{:author_values=>"Bob", :min_created_at=>Time.zone.parse('Sun, 01 Feb 2015 00:00:00 UTC +00:00'), :max_created_at=>Time.parse('Sat, 28 Feb 2015 23:59:59.999999999 UTC +00:00')}},
        {:y=>0, :filters=>{:author_values=>"Jim", :min_created_at=>Time.zone.parse('Sun, 01 Feb 2015 00:00:00 UTC +00:00'), :max_created_at=>Time.parse('Sat, 28 Feb 2015 23:59:59.999999999 UTC +00:00')}},
        {:y=>1, :filters=>{:author_values=>"Meg", :min_created_at=>Time.zone.parse('Sun, 01 Feb 2015 00:00:00 UTC +00:00'), :max_created_at=>Time.parse('Sat, 28 Feb 2015 23:59:59.999999999 UTC +00:00')}},
        {:y=>1, :filters=>{:author_values=>"Sue", :min_created_at=>Time.zone.parse('Sun, 01 Feb 2015 00:00:00 UTC +00:00'), :max_created_at=>Time.parse('Sat, 28 Feb 2015 23:59:59.999999999 UTC +00:00')}}]},
      {:name=>"2015-03-01 00:00:00 UTC",
       :data=>
       [{:y=>1, :filters=>{:author_values=>"Bob", :min_created_at=>Time.zone.parse('Sun, 01 Mar 2015 00:00:00 UTC +00:00'), :max_created_at=>Time.parse('Tue, 31 Mar 2015 23:59:59.999999999 UTC +00:00')}},
        {:y=>1, :filters=>{:author_values=>"Jim", :min_created_at=>Time.zone.parse('Sun, 01 Mar 2015 00:00:00 UTC +00:00'), :max_created_at=>Time.parse('Tue, 31 Mar 2015 23:59:59.999999999 UTC +00:00')}},
        {:y=>1, :filters=>{:author_values=>"Meg", :min_created_at=>Time.zone.parse('Sun, 01 Mar 2015 00:00:00 UTC +00:00'), :max_created_at=>Time.parse('Tue, 31 Mar 2015 23:59:59.999999999 UTC +00:00')}},
        {:y=>0, :filters=>{:author_values=>"Sue", :min_created_at=>Time.zone.parse('Sun, 01 Mar 2015 00:00:00 UTC +00:00'), :max_created_at=>Time.parse('Tue, 31 Mar 2015 23:59:59.999999999 UTC +00:00')}}]}
    ])

    expect {
      Repor::Exporters::Highcharts.new(CommentReport.new(x_axes: %w(author created_at likes), y_axis: 'comment_count'))
    }.to raise_error("can't generate chart for more than 2 x-axes")
  end
end
