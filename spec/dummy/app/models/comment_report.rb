class CommentReport < Repor::Report
  report_on :Comment

  def default_x_axis
    :author
  end

  # bare
  enum_dimension :author
  time_dimension :created_at
  hist_dimension :likes

  # with a relation
  enum_dimension :post_title, expression: 'posts.title', relation: ->(r) { r.joins(:post) }
  time_dimension :post_created_at, expression: 'posts.created_at', relation: ->(r) { r.joins(:post) }
  hist_dimension :post_likes, expression: 'posts.likes', relation: ->(r) { r.joins(:post) }

  aggregator :comment_count, ->(r) { r.count }
  aggregator :average_likes, ->(r) { r.average('comments.likes') }, formatter: ->(v) { v.to_f.round(2) }
end
