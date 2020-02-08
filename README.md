# Chop

Slice and dice your Cucumber tables with ease! Assumes usage of ActiveRecord and Capybara.

[![Build Status](https://travis-ci.org/botandrose/chop.svg?branch=master)](https://travis-ci.org/botandrose/chop)
[![Code Climate](https://codeclimate.com/github/botandrose/chop/badges/gpa.svg)](https://codeclimate.com/github/botandrose/chop)

## Installation

```ruby
group :test do
  gem 'chop'
end
```

## Usage

Chop monkeypatches Cucumber tables with three new methods:

* `#create!`: Creates entities. Built-in support for ActiveRecord (default) and FactoryGirl, at present.
* `#diff!`: Enhances existing method to also accept a capybara element, or a CSS selector pointing to one. Currently supports diffing `<table>`, `<dl>`, `<ul>`, and even `<form>`!.
* `#fill_in!`: Fills in a form on the current page.

All these methods accept blocks for customization.

### Configuration methods for `Chop`:

* `.register_creation_strategy`: Provide a key and a block to register alternate strategies for `.create!`, e.g. FactoryGirl.

### Block methods for `#create!`:

Transform the attributes hash derived from the table before passing to `ActiveRecord.create!`.

High-level declarative transformations:

* `#file`: Replaces a file path with a file handle. Looks in `features/support/fixtures` by default.
* `#files`: Replaces a space-delimited list of file paths with an array of file handles. Looks in `features/support/fixtures` by default.
* `#has_one/#belongs_to`: Replaces an entity name with that entity. Uses `.find_by_name` by default.
* `#has_many`: Replaces a comma-delimited list of entity names with an array of those entities. Uses `.find_by_name` by default.
* `#underscore_keys`: Converts all hash keys to underscored versions.
* `#default`: Provides a default value for a given field.
* `#copy`: Copies the value of one or more fields.
* `#rename`: Renames one or more fields.
* `#delete`: Deletes one or more fields.

All these methods are implemented in terms of the following low-level methods, useful for when you need more control over the transformation:
* `#field`: performs transformations on a specific field value.
* `#transformation`: performs transformations on the attributes hash.

Lifecycle hooks:
* `#after`: Temporarily removes zero or more fields, and then after record creation, yields them to the block, along with the created record.
* `#create`: Override the default creation strategy.

### Block methods for `#diff!`:

Transform the table of Capybara nodes before converting them to text and passing to `diff!`.

Overide Capybara finders:
* `#rows`: overrides existing default row finder.
* `#cells`: overrides existing default cell finder.
* `#text`: overrides existing default text finder.
* `#allow_not_found`: diffing against a missing element will diff against `[[]]` instead of raising an exception.

High-level declarative transformations:
* `#image`: Replaces the specified cell with the filename of the first image within it, stripped of path and cachebusters.

All these methods are implemented in terms of the following low-level methods, useful for when you need more control over the transformation:
* `#header`: add or transform the table header, depending on block arity.
* `#header(key)`: transform the specified header column, specified either by numeric index, or by hash key.
* `#field`: performs transformations on a specific field value.
* `#hash_transformation`: performs arbitrary transformations on an array of hashes constructed by assuming a header row. Hash keys are downcased and underscored.
* `#transformation`: performs arbitrary transformations on the 2d array of Capybara nodes.

### Block methods for `#fill_in!`:

TODO: Does this make sense?

### Example

```gherkin
# features/manage_industries.feature

Given the following industries exist:
  | name             | wall_background | table_background |
  | Another industry | wall.jpg        | table.jpg        |
  | Example industry | wall.jpg        | table.jpg        |

Given the following stories exist:
  | industry         | image       | headline         |
  | Example industry | example.jpg | Example headline |
  | Example industry | example.jpg | Another headline |

Given I am on the home page

When I fill in the following form:
  | Name             | NEW industry  |
  | Wall background  | NEW_wall.jpg  |
  | Table background | NEW_table.jpg |

Then I should see the following industries:
  | ANOTHER INDUSTRY |
  | EXAMPLE INDUSTRY |
And I should see the following "EXAMPLE INDUSTRY" stories:
  | IMAGE       | HEADLINE         |
  | example.jpg | Example headline |
  | example.jpg | Another headline |
```

```ruby
# features/step_definition/industry_steps.rb

Given "the following industries exist:" do |table|
  table.create! ConversationTable::Industry do
    rename({
      :wall_background => wall_background_file,
      :table_background => table_background_file,
    })
    file :wall_background_file, :table_background_file
  end
end

Given "the following stories exist:" do |table|
  table.create! factory_girl: "conversation_table/story" do
    belongs_to :industry, ConversationTable::Industry

    rename :image => :image_file
    file :image_file

    # The previous two lines can also be expressed as:
    file :image => :image_file
  end
end

When "I fill in the following form:" do |table|
  table.fill_in!
end

Then "I should see the following industries:" do |table|
  table.diff! "dl"
end

Then /^I should see the following "(.+?)" stories:$/ do |industry_name, table|
  within "dfn", text: industry_name do
    table.diff! "table" do
      image :image
    end
  end
end
```

### Don't like monkeypatching?

Load `chop` before `cucumber` in your Gemfile, and call the two methods directly on the `Chop` module, passing the cucumber table in as the last argument.

```ruby
Chop.create! Users, table
Chop.diff! "table", table
Chop.fill_in! table
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/botandrose/chop.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

