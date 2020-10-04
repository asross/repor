class PostReport < ActiveReporter::Report
  report_on :post
  count_aggregator :count
  sum_aggregator :total_likes, attribute: :likes
  min_aggregator :min_likes, attribute: :likes
  min_aggregator :min_created_at, attribute: :created_at
  max_aggregator :max_likes, attribute: :likes
  max_aggregator :max_created_at, attribute: :created_at
  average_aggregator :avg_likes, attribute: :likes
  array_aggregator :post_ids, attribute: :id
  category_dimension :author, model: :authors, attribute: :name, relation: ->(r) { r.joins('LEFT OUTER JOIN authors ON authors.id = posts.author_id') }
  number_dimension :likes
  time_dimension :created_at
end
