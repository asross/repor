class PostReport < Repor::Report
  report_on :Post
  count_aggregator :count
  sum_aggregator :total_likes, expression: 'posts.likes'
  min_aggregator :min_likes, expression: 'posts.likes'
  min_aggregator :min_created_at, expression: 'posts.created_at'
  max_aggregator :max_likes, expression: 'posts.likes'
  max_aggregator :max_created_at, expression: 'posts.created_at'
  avg_aggregator :avg_likes, expression: 'posts.likes'
  array_aggregator :post_ids, expression: 'posts.id'
  category_dimension :author, expression: 'authors.name', relation: ->(r) { r.joins(:author) }
  number_dimension :likes
  time_dimension :created_at
end
