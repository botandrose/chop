# Chop

Slice and dice your Cucumber tables with ease!

## Installation

```ruby
group :test do
  gem 'chop'
end
```

## Usage

TODO: Write more usage instructions here. See the source for usage in the meantime.

* `Chop::Builder`: Create ActiveRecord instances from a Cucumber table.

* `Chop::Table`: Diff a Cucumber table with a <table>.
* `Chop::DefinitionList`: Diff a Cucumber table with a <dl>.
* `Chop::UnorderedList`: Diff a Cucumber table with a <ul>.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/botandrose/chop.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

