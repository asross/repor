# Repor [![Build Status](https://api.travis-ci.org/asross/repor.svg?branch=master)](https://travis-ci.org/asross/repor)

`repor` is a framework for aggregating data about
[Rails](http://rubyonrails.org) models backed by
[PostgreSQL](http://www.postgresql.org), [MySQL](https://www.mysql.com), or
[SQLite](https://www.sqlite.org) databases.  It's designed to be flexible
enough to accommodate many use cases, but opinionated enough to avoid the need
for boilerplate.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Basic usage](#basic-usage)
- [Building reports](#building-reports)
- [Defining reports](#defining-reports)
  - [Base relation](#base-relation)
  - [Dimensions (x-axes)](#dimensions-x-axes)
    - [Filtering by dimensions](#filtering-by-dimensions)
    - [Grouping by dimensions](#grouping-by-dimensions)
    - [Customizing dimensions](#customizing-dimensions)
  - [Aggregators (y-axes)](#aggregators-y-axes)
    - [Customizing aggregators](#customizing-aggregators)
- [Serializing reports](#serializing-reports)
- [Contributing](#contributing)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Basic usage

Here are some examples of how to define, run, and serialize a `Repor::Report`:

```ruby
class PostReport < Repor::Report
  report_on :Post

  category_dimension :author, relation: ->(r) { r.joins(:author) },
    expression: 'users.name'
  number_dimension :likes
  time_dimension :created_at

  count_aggregator :number_of_posts
  sum_aggregator :total_likes, expression: 'posts.likes'
  array_aggregator :post_ids, expression: 'posts.id'
end

# show me # published posts from 2014-2015 with at least 4 likes, by author

report = PostReport.new(
  relation: Post.published,
  groupers: [:author],
  aggregator: :number_of_posts,
  dimensions: {
    likes: {
      only: { min: 4 }
    },
    created_at: {
      only: { min: '2014', max: '2015' }
    }
  }
)

puts report.data

# => [
#  { key: 'James Joyce', value: 10 },
#  { key: 'Margaret Atwood', value: 4 }
#  { key: 'Toni Morrison', value: 5 }
# ]

# show me likes on specific authors' posts by author and year, from 1985-1987

report = PostReport.new(
  groupers: [:author, :created_at],
  aggregator: :total_likes,
  dimensions: {
    created_at: {
      only: { min: '1985', max: '1987' },
      bin_width: 'year'
    },
    author: {
      only: ['Edith Wharton', 'James Baldwin']
    }
  }
)

puts report.data

# => [{
#   key: { min: Tue, 01 Jan 1985 00:00:00 UTC +00:00,
#          max: Wed, 01 Jan 1986 00:00:00 UTC +00:00 },
#   values: [
#     { key: 'Edith Wharton', value: 35 },
#     { key: 'James Baldwin', value: 13 }
#   ]
# }, {
#   key: { min: Wed, 01 Jan 1986 00:00:00 UTC +00:00,
#          max: Thu, 01 Jan 1987 00:00:00 UTC +00:00 },
#   values: [
#     { key: 'Edith Wharton', value: 0 },
#     { key: 'James Baldwin', value: 0 }
#   ]
# }, {
#   key: { min: Thu, 01 Jan 1987 00:00:00 UTC +00:00,
#          max: Fri, 01 Jan 1988 00:00:00 UTC +00:00 },
#   values: [
#     { key: 'Edith Wharton', value: 0 },
#     { key: 'James Baldwin', value: 19 }
#   ]
# }]

csv_serializer = Repor::Serializers::CsvSerializer.new(report)
puts csv_serializer.csv_text

# => csv text string

chart_serializer = Repor::Serializers::HighchartsSerializer.new(report)
puts chart_serializer.highcharts_options

# => highcharts options hash
```

To define a report, you declare dimensions (which represent attributes of your
data) and aggregators (which represent quantities you want to measure). To
run a report, you instantiate it with one aggregator and at least one dimension,
then inspect its `data`. You can also wrap it in a serializer to get results in
useful formats.

## Building reports

Just call `ReportClass.new(params)`, where `params` is a hash with these keys:

- `aggregator` (required) is the name of the aggregator to aggregate by
- `groupers` (required) is a list of the names of the dimension(s) to group by
- `relation` (optional) provides an initial scope for the data
- `dimensions` (optional) holds dimension-specific filter or grouping options

See below for more details about dimension-specific parameters.

## Defining reports

### Base relation

A `Repor::Report` either needs to know what `ActiveRecord` class it is reporting
on, or it needs to know a `table_name` and a `base_relation`.

You can specify an `ActiveRecord` class by calling the `report_on` class method
with a class or class name, or if you prefer, you can override the other two as
instance methods.

By default, it will try to infer an `ActiveRecord` class from the report class
name by dropping `/Report$/` and constantizing.

```ruby
class PostReport < Repor::Report
end

PostReport.new.table_name
# => 'posts'

PostReport.new.base_relation
# => Post.all

class PostStructuralReport < Repor::Report
  report_on :Post

  def base_relation
    super.where(author: 'Foucault')
  end
end

PostStructuralReport.new.table_name
# => 'posts'

PostStructuralReport.new.base_relation
# => Post.where(author: 'Foucault')
```

Finally, you can also use `autoreport_on` if you'd like to automatically infer
dimensions from your columns and associations. `autoreport_on` will try to map
most columns to dimensions, and if the column in question is for a `belongs_to`
association, will even try to join and report on the association's name:
```
class PostReport < Repor::Report
  autoreport_on Post
end

PostReport.new.dimensions.keys
# => %i[:created_at, :updated_at, :likes, :title, :author]

PostReport.new.dimensions[:author].expression
# => 'users.name'
```

Autoreport behavior can be customized by overriding certain methods; see the
`Repor::Report` code for more information.

### Dimensions (x-axes)

You define dimensions on your `Repor::Report` to represent attributes of your
data you're interested in. Dimensions objects can filter or group your relation
by a SQL expression, and accept/return simple Ruby values of various types.

There are several built-in types of dimensions:
- `CategoryDimension`
    - Groups/filters the relation by the discrete values of the `expression`
- `NumberDimension`
    - Groups/filters the relation by binning a continuous numeric `expression`
- `TimeDimension`
    - Like number dimensions, but the bins are increments of time

You define dimensions in your report class like this:

```ruby
class PostReport < Repor::Report
  category_dimension :status
  number_dimension :author_rating, expression: 'users.rating',
    relation: ->(r) { r.joins(:author) }
  time_dimension :publication_date, expression: 'posts.published_at'
end
```

The SQL expression a dimension uses defaults to:
```ruby
"#{report.table_name}.#{dimension.name}"
```

but this can be overridden by passing an `expression` option. Additionally, if
the filtering or grouping requires joins or other SQL operations, a custom
`relation` proc can be passed, which will be called beforehand.

#### Filtering by dimensions

All dimensions can be filtered to one or more values by passing in
`params[:dimensions][<dimension name>][:only]`.

`CategoryDimension#only` should be passed the exact values you'd like to filter
to (or what will map to them after connection adapter quoting).

`NumberDimension` and `TimeDimension` are "bin" dimensions, and their `only`s
should be passed one or more bin ranges. Bin ranges should be hashes of at
least one of `min` and `max`, or they should just be `nil` to explicitly select
rows for which `expression` is null. Bin range filtering is `min`-inclusive but
`max`-exclusive. For `NumberDimension`, the bin values should be numbers or
strings of digits. For `TimeDimension`, the bin values should be dates/times or
`Time.zone.parse`-able strings.

#### Grouping by dimensions

To group by a dimension, pass its `name` to `params[:groupers]`.

For bin dimensions (`NumberDimension` and `TimeDimension`), where the values
being grouped by are ranges of numbers or times, you can specify additional
options to control the width and distribution of those bins. In particular,
you can pass values to:

- `params[:dimensions][<name>][:bins]`,
- `params[:dimensions][<name>][:bin_count]`, or
- `params[:dimensions][<name>][:bin_width]`

`bins` is the most general option; you can use it to divide the full domain of
the data into non-uniform, overlapping, and even null bin ranges. It should be
passed an array of the same min/max hashes or `nil` used in filtering.

`bin_count` will divide the domain of the data into a fixed number of bins. It
should be passed a positive integer.

`bin_width` will tile the domain with bins of a fixed width. It should be
passed a positive number for `NumberDimension`s and a "duration" for
`TimeDimension`s. Durations can either be strings of a number followed by a time
increment (minutes, hours, days, weeks, months, years), or they can be hashes
suitable for use with
[`ActiveSupport::TimeWithZone#advance`](http://apidock.com/rails/ActiveSupport/TimeWithZone/advance).
E.g.:

```
params[:dimensions][<time dimension>][:bin_width] = '1 month'
params[:dimensions][<time dimension>][:bin_width] = { months: 2, hours: 2 }
```

`NumberDimension`s will default to using 10 bins and `TimeDimension`s will
default to using a sensical increment of time given the domain; you can
customize this by overriding methods in those classes.

Note that when you inspect `report.data` after grouping by a bin dimension, you
will see the dimension values are actually `Repor::BinDimension::Bin` objects,
which respond to `min`, `max`, and various json/Hash methods. These are meant
to provide a common interface for the different types of bins (double-bounded,
unbounded on one side, null) and handle mapping between SQL and Ruby
representations of their values. You may find bin objects useful in working
with report data, and they can also be customized.

If you want to change how `repor` maps SQL values to the dimension values of
`report.data`, you can override `YourDimension#sanitize_sql_value`.

#### Customizing dimensions

You can define custom dimension classes by inheriting from one of the existing
ones:
```ruby
class CaseInsensitiveCategoryDimension < Repor::Dimensions::CategoryDimension
  def order_expression
    "UPPER(#{super})"
  end
end
```

You can then use it in the definition of a report class like this:
```ruby
class UserReport < Repor::Report
  dimension :last_name, CaseInsensitiveCategoryDimension
end
```

Common methods to override include `order_expression`, `sanitize_sql_value`,
`validate_params!`, `group_values`, and `default_bin_width`.

Note that if you inherit directly from  `Repor::Dimensions::BaseDimension`, you
will need to implement (at a minimum) `filter(relation)`, `group(relation)`, and
`group_values`. See the base dimension class for more details.

If you want custom behavior for bins, you can define `Bin` and `BinTable`
classes nested inside your custom dimension classes (or override methods
directly on `Repor::BinDimension::Bin(Table)`,
`Repor::TimeDimension::Bin(Table)`, etc). See the relevant classes for more
details.

### Aggregators (y-axes)

Aggregators take your groups and reduce them down to a single value. They
represent the quantities you're looking to measure across your dimensions.

There are several built-in types of aggregators:

- `CountAggregator`
    - counts the number of distinct records in each group
- `SumAggregator`
    - sums an `expression` over each distinct record in each group
- `AvgAggregator`
    - sum divided by count
- `MinAggregator`
    - finds the minimum value of `expression` in each group
- `MaxAggregator`
    - finds the maximum value of `expression` in each group
- `ArrayAggregator`
    - returns an array of `expression` values in each group (PostgreSQL only)
    - useful if you want to drill down into the data behind an aggregation

#### Customizing aggregators

By default, the `expression` will default to the aggregator name, but you can
achieve some level of customization by passing in `expression` or `relation`:

```ruby
max_aggregator :max_likes, expression: 'posts.likes'

sum_aggregator :total_cost,
  expression: 'invoices.hours_worked * invoices.hourly_rate'

avg_aggregator :mean_author_age, expression: 'AGE(users.dob)',
  relation: ->(r) { r.joins(:author) }
```

You can also define your own aggregator type if none of the existing ones meet
your needs:

```ruby
class StandardDeviationAggregator < Repor::Aggregators::BaseAggregator
  def aggregate(grouped_relation)
    # check out the other aggregators for examples of what to do here.
  end
end

# then:
aggregator :sigma_likes, StandardDeviationAggregator, expression: 'posts.likes'
```

## Serializing reports

After defining and running a report, you can wrap it in a serializer to get its
data in a more useful format.

`TableSerializer` defines `caption`, `headers`, and `each_row`, which can be
used to construct a table. It also wraps dimension and aggregator names and
values in formatting methods, which can be overridden, e.g. if you would like to
use I18n for date or enum column formatting. You can override these methods on
`BaseSerializer` if you would like them to apply everywhere.

`CsvSerializer` dumps the data from `TableSerializer` to a CSV string or file.

`HighchartsSerializer` can map reports with 1-3 grouping dimensions to options
for passing into the Highcharts charting library. Extra options included with
the raw data makes it easy to implement features like detailed tooltips and
drilldown.

`FormFieldSerializer` represents report parameters as HTML form fields. Likely
you will want to implement your own form logic specific to your report class
and application design, but it provides an easy and somewhat extensible way to
get up and running.

See the serializer class files for more documentation.

## Contributing

If you have suggestions for how to make any part of this library better, or if
you want to contribute extra dimensions, aggregators, serializers, please
submit them in a pull request (with test coverage).

To work on developing `repor`, you will need to have Ruby and PostgreSQL,
MySQL, or SQLite3 installed. Then clone the repository and run:
```sh
bundle install
cd spec/dummy
DB=<your db type> bundle exec rake db:create db:schema:load db:test:prepare
cd ../..
DB=<your db type> bundle exec rspec
```

which will run the test suite. The options for `DB` are `sqlite`, `mysql`, and
`postgres` (the default). Preferably you should run it against all three, but
CI will also do so.

To see the dummy application in development mode, you can run:
```sh
cd spec/dummy
DB=<your db type> bundle exec rake db:setup
DB=<your db type> bundle exec rails server
```

## License

[MIT](http://opensource.org/licenses/MIT)
