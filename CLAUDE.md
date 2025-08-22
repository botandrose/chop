# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chop is a Ruby gem that enhances Cucumber tables with three main methods: `#create!` for creating entities (ActiveRecord/FactoryGirl support), `#diff!` for comparing tables against HTML elements (table, dl, ul, form), and `#fill_in!` for form filling. It works by monkey-patching Cucumber's DataTable class.

## Development Commands

### Testing
- `rake spec` or `bundle exec rspec` - Run the full test suite
- `rspec spec/chop/table_spec.rb` - Run a specific test file 
- `rspec spec/chop/table_spec.rb:42` - Run a specific test by line number

### Development Setup
- `bin/setup` - Install dependencies after checkout
- `bin/console` - Interactive console for experimentation

### Multi-Version Testing
- `bundle exec appraisal install` - Install gems for all Rails versions
- `bundle exec appraisal rails-7.0 rspec` - Test against specific Rails version
- `bundle exec appraisal rspec` - Test against all Rails versions

### Gem Management
- `rake build` - Build the gem
- `rake release` - Release new version (updates version, tags, pushes)

## Architecture

### Core Components
- **`Chop::DSL`** (lib/chop/dsl.rb) - Main interface providing `create!`, `diff!`, `fill_in!` methods
- **`Chop::Create`** (lib/chop/create.rb) - Handles entity creation with transformation DSL
- **`Chop::Diff`** (lib/chop/diff.rb) - Base class for HTML element diffing with Capybara
- **Element-specific diffing classes**:
  - `Chop::Table` - HTML table diffing
  - `Chop::DefinitionList` - Definition list (`<dl>`) diffing  
  - `Chop::UnorderedList` - Unordered list (`<ul>`) diffing
  - `Chop::Form` - Form filling functionality

### Monkey-patching Strategy
The gem extends `Cucumber::MultilineArgument::DataTable` by prepending a module that adds the three main methods. The DSL module can also be called directly as `Chop.create!`, `Chop.diff!`, `Chop.fill_in!` to avoid monkey-patching.

### Creation Strategies
Supports pluggable creation strategies via `Chop::Create.register_creation_strategy`:
- Default: ActiveRecord's `create!`
- FactoryGirl/FactoryBot support built-in
- Custom strategies can be registered

### Transformation DSL
The `#create!` method supports a rich DSL for transforming table data:
- Field transformations: `file`, `files`, `has_one`, `has_many`, `default`, `copy`, `rename`, `delete`
- Low-level: `field`, `transformation` for custom logic
- Lifecycle hooks: `after` for post-creation logic

## Testing Patterns

- Uses RSpec with `spec_helper.rb` configuring focus and run-all behavior
- Tests organized by component in `spec/chop/` matching `lib/chop/` structure
- Tests cover both direct method calls and monkey-patched table behavior
- Uses Capybara for integration testing of diffing functionality