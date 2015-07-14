# Repor

`repor` is a DSL for aggregating data about Rails models. It's designed to be flexible enough to accomodate many use cases, but opinionated enough to avoid boilerplate.

## Basic Usage

Here's an example of how to write and use a `Repor::Report`:

```ruby
class PostReport < Repor::Report
  enum_dimension :author, relation: ->(r) { r.joins(:author) }, expression: 'users.name'
  time_dimension :created_at
  hist_dimension :likes

  aggregator :count, ->(r) { r.count }
  aggregator :total_likes, ->(r) { r.sum('posts.likes') }
end

# show me counts of all posts from 2014-2015 with at least 4 likes by author

puts PostReport.new(
  relation: Post.published,
  min_likes: 4,
  min_created_at: '2014',
  max_created_at: '2015',
  x_axis: 'author',
  y_axis: 'count'
).formatted_data

# => { 'Mark Zuckerberg' => 10, 'Jane Kraczinsky' => 4, 'Bayard Rustin' => 5 }

# show me likes on specific authors' posts by author and year, from 1985-1987

puts PostReport.new(
  author_values: ['Toni Morrison', 'James Joyce', 'Margaret Atwood'],
  x_axes: ['author', 'created_at'],
  y_axis: 'total_likes',
  created_at_time_step: 'year',
  min_created_at: '1985',
  max_created_at: '1987'
).formatted_data

# => {
#  ['Toni Morrison', '1985'] => 3,  ['James Joyce', '1985'] => 3, ['Margaret Atwood', '1985'] => 15,
#  ['Toni Morrison', '1986'] => 4,  ['James Joyce', '1986'] => 0, ['Margaret Atwood', '1986'] => 10,
#  ['Toni Morrison', '1987'] => 19, ['James Joyce', '1987'] => 1, ['Margaret Atwood', '1987'] => 6
# }
```

To write a report class, you define dimensions and aggregators. Dimensions are your x-axes and aggregators are your y-axes. You can then use that report class by instantiating it with one `y_axis` and at least one `x_axis` and calling one of the data access methods. You can also wrap it in an exporter to get that data in CSV or highcharts form.

## Initialization Options

General options:

- `y_axis` picks which aggregator to use
- `x_axis`, `x_axis2`, `x_axes` pick which dimension(s) to group by
- `relation` provides an initial scope for the data (useful if you want to limit the report to records a user is authorized to see, without making that logic part of the report itself).

Dimension-specific options:

- Enumerated dimensions
    * `#{dimension}_values` - pass in a single value or an array to filter to specific dimension values
- Time dimensions
    * `min_#{dimension}` - pass a time or parseable string to filter to all records at or after a particular time
    * `max_#{dimension}` - filter to all records at or before a particular time
    * `#{dimension}_time_step` - control whether time binning is by year, month, day, etc.
- Numeric (histogram) dimensions
    * `min_#{dimension}` - pass a number or a string parseable as one to filter to records with dimension >= that value
    * `max_#{dimension}` - sets the maximum value
    * `#{dimension}_bin_size`, `#{dimension}_bin_count` - control the size of the histogram binning

## Defining Axes

### Aggregators (y axes)

Add y-axis options by calling `aggregator` with the name of the axis and a `Proc` that will take a grouped `ActiveRecord::Relation` and return a hash of `[x_axis_values...] => scalar`. For example:

```ruby
class PostReport < Repor::Report
  aggregator :total_likes, ->(r) { r.sum('posts.likes') }
  aggregator :all_likes, ->(r) { r.joins(:comments).sum('posts.likes + comments.likes') }
end
```

### Dimensions (x axes/filters)

Add dimensions, which are both x-axis and filter options, by calling one of the dimension builder methods (`enum_dimension`, `time_dimension`, `hist_dimension`) with the name. You can optionally pass a `relation` proc and a SQL `expression`, and there are a few dimension-type specific options you can pass as well.

The dimension builder class methods will define several helper instance methods (plus additional methods specific to the dimension type):
- `grouped_by_#{dimension}`
- `filtered_by_#{dimension}`
- `relation_for_#{dimension}`
- `all_#{dimension}_values`
- `sanitize_#{dimension}_value`
- `format_#{dimension}_value`

All of these methods can be overridden once defined (with support for `super`).

#### Enumerated Dimensions

Enumerated dimensions are for reporting on expressions that can take on a set of possible values. For example, if you have a `Post` model with a `status` column and an `author` association, you might want to do something like the following:

```ruby
class PostReport < Repor::Report
  aggregator :count, ->(r) { r.count }
  enum_dimension :status
  enum_dimension :author, relation: ->(r) { r.joins(:author) }, expression: 'users.name'
end
```

Which would allow you to do:

```ruby
puts PostReport.new(x_axis: 'status').formatted_data

# => { 'Draft' => 145, 'Published' => 453, 'Archived' => 73 }

puts PostReport.new(x_axis: 'author').formatted_data

# => { 'Alice Jones' => 35, 'Bob Jones' => 78, 'Chester Jones' => 12 }
```

To filter, you can pass `params[:status_values] = 'Draft'` to limit the report to posts for which `posts.status = 'Draft'`, and `params[:status_values] = ['Draft', 'Published']` to limit the report to posts for which `posts.status IN ('Draft', 'Published')`.

#### Time Dimensions

Time dimensions allow you to group your data by the year, month, week, day, or even the hour/minute/second of some timestamp.

The time step can be passed in as an option when initializing the report, but if it's not, a sensible one will be inferred from the total period spanned by the data.

For example, you might have

```ruby
class PostReport < Repor::Report
  aggregator :count, ->(r) { r.count }
  time_dimension :created_at
end
```

Which might produce:

```ruby
puts PostReport.new(x_axis: 'created_at', y_axis: 'count').formatted_data

# => { 'May 2015' => 124, 'Jun 2015' => 163, 'Jul 2015' => 122 }
```

If you wanted to report by week, you could pass in `params[:created_at_time_step] = 'week'`. If you wanted to change how the default time step is calculated (maybe to always return `'week'`), you could override `PostReport#default_created_at_time_step`.

Time dimensions will return data ordered chronologically from the beginning to the end of the full time range, and will include entries without records for completeness.

Defining a time dimension allows you to filter by the minimum and/or maximum time. If your dimension is called `created_at`, you can pass in any combination of `params[:min_created_at]` and `params[:max_created_at]`, which can be parseable strings, dates, or datetimes.

#### Histogram Dimensions

If you have some numeric value that you would like to report on, you can report on the distribution of its values using a histogram. E.g.:

```ruby
class PostReport < Repor::Report
  aggregator :count, ->(r) { r.count }
  hist_dimension :likes
end
```

might output data of the form:

```ruby
puts PostReport.new(x_axis: 'likes', y_axis: 'count').formatted_data

# => { 0 => 563, 5 => 231, 10 => 117, 15 => 32, 20 => 7 }
```

You can pass in the number of bins you would like or the size of each bin by passing `params[:likes_bin_size]` or `params[:likes_bin_count]`. It will default to picking a bin size that ensures 5 bins. You can also override `PostReport#default_likes_bin_size` or `#default_likes_bin_count`.

Again as with time, we will return data ordered from least to greatest and include bins with no records. And you can filter by the histogram dimension by passing in, in this case, `params[:min_number_of_likes]` and `params[:max_number_of_likes]`.

## Specifying a model

`repor` needs to know which `ActiveRecord` model it's reporting on. You can specify it manually by using the `report_on` method:

```ruby
class WackyReport
  report_on 'Post'
end
```

If you don't specify a model, `repor` will attempt to infer it by taking the demodulized report class name and removing `/Report$/` (so `SomeModule::SomeClassReport` will be assumed to report on `SomeClass`).

## Formatting

By default, calling `.data` on a report will produce a hash of `{ [x_values...] => y_value }`. The x values for enumerated dimensions will be whatever comes out of the database. The x values for time and histogram dimensions will be `Range`s of times and floats, respectively.

If you call `.formatted_data`, formatting is applied to all of these values to make them user-friendly (via overrideable methods):

```ruby
class PostReport < Repor::Report
  def format_enum(value, dimension)
    I18n.t("post_report.#{dimension}_values.#{value}")
  end

  def format_hist(range, dimension, bin_size)
    "#{range.min} <= #{dimension} < #{range.max}"
  end

  def format_created_at_value(range, dimension, time_step)
    "created during #{time_step} of #{range.min}"
  end
end
```

For enumerated dimensions, we just return the value as-is, but you might override that globally or dimension-by-dimension to, for example, call out to `I18n`. Override `format_#{dimension}_value` for dimension-specific formatting and `format_enum` for global enum formatting.

For time dimensions, we try to format the time interval based on the time step, using a set of `strftime` options. Again, override `format_#{dimension}_value` or `format_time`.

For histogram dimensions, we just return the minimum value. Can be overridden in the same manner.

You can also format y axis values by passing a `formatter` option:

```ruby
class PostReport < Repor::Report
  aggregator :average_likes, ->(r) { r.average('posts.likes') }, formatter: ->(v) { v.to_f.round(2) }
end
```

The formatting logic in `repor` is not fully fleshed out yet, and it's likely we will move towards a solution that more cleanly separates the formatting logic from the underlying report logic (while keeping it easy to customize).

## Output

### CSV

Use `Repor::Exporters::CSV.new(report).csv` to get a report's data as a CSV.

### Highcharts

Use `Repor::Exporters::Highcharts.new(report).highcharts_options` to get a report's data as options you can pass directly into highcharts to generate a graph. The filter parameters necessary to get data for only a specific point are embedded in that point's attributes, making it easy to implement features such as drilldown.

You can extend this class to merge in additional highcharts options, either globally or for specific series/points (see [Highcharts docs](http://api.highcharts.com/highcharts#series<column>.data)):

```ruby
class CustomHighchartsExporter < Repor::Exporters::Highcharts
  def point_options(x_values, y_value)
    super.merge(colors_for(x_values, y_value))
  end

  def highcharts_options
    super.merge(subtitle: { text: "A great chart subtitle" })
  end
end
```

## Contributing

If you have suggestions for how to make any part of the codebase better, or if you want to contribute extra dimension types and/or exporters, please submit them as a pull request to this repository (with test coverage).

## License

[MIT](http://opensource.org/licenses/MIT)
