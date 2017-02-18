# Chop

Slice and dice your Cucumber tables with ease! Assumes usage of ActiveRecord and Capybara.

## Installation

```ruby
group :test do
  gem 'chop'
end
```

## Usage

Chop monkeypatches Cucumber tables with two new methods:

* `#build!`: Creates ActiveRecord instances.
* `#diff!`: Enhances existing method to also accept a CSS selector. Currently supports diffing `<table>`, `<dl>`, and `<ul>`.

Both these methods accept blocks for customization.

### Block methods for `#build!`:

Transform the attributes hash derived from the table before passing to `ActiveRecord.create!`.

High-level declarative transformations:

* `#file`: Replaces a file path with a file handle. Looks in `features/support/fixtures` by default.
* `#files`: Replaces a space-delimited list of file paths with an array of file handles. Looks in `features/support/fixtures` by default.
* `#has_one/#belongs_to`: Replaces an entity name with that entity. Uses `.find_by_name` by default.
* `#has_many`: Replaces a comma-delimited list of entity names with an array of those entities. Uses `.find_by_name` by default.
* `#underscore_keys`: Converts all hash keys to underscored versions.

All these methods are implemented in terms of the following low-level methods, useful for when you need more control over the transformation:
* `#field`: performs transformations on a specific field value.
* `#transformation`: performs transformations on the attributes hash.

### Block methods for `#diff!`:

TODO: Pending API overhaul. 

### Example

```gherkin
# features/manage_industries.feature

Given the following industries exist:
  | name              | wall_background_file | table_background_file |
  | Another industry  | wall.jpg             | table.jpg             |
  | Example industry  | wall.jpg             | table.jpg             |

Given the following stories exist:
  | industry          | image_file   | headline          |
  | Example industry  | example.jpg  | Example headline  |
  | Example industry  | example.jpg  | Another headline  |

Given I am on the home page
Then I should see the following industries:
  | ANOTHER INDUSTRY |
  | EXAMPLE INDUSTRY |
And I should see the following "EXAMPLE INDUSTRY" stories:
  | IMAGE       | HEADLINE          |
  | example.jpg | Example headline  |
  | example.jpg | Another headline  |
```

```ruby
# features/step_definition/industry_steps.rb

Given "the following industries exist:" do |table|
  table.create! ConversationTable::Industry do
    file :wall_background_file, :table_background_file
  end
end

Given "the following stories exist:" do |table|
  table.create! ConversationTable::Story do
    belongs_to :industry, ConversationTable::Industry
    file :image_file
  end
end

Then "I should see the following industries:" do |table|
  table.diff! "dl"
end

Then /^I should see the following "(.+?)" stories:$/ do |industry_name, table|
  within "dfn", text: industry_name do
    table.diff! "table"
  end
end
```

### Don't like monkeypatching?

Load `chop` before `cucumber` in your Gemfile, and call the two methods directly on the `Chop` module, passing the cucumber table in as the first argument.

```ruby
Chop.build! table, Users
Chop.diff! table, "table"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/botandrose/chop.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

