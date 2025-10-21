# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chop is a Ruby gem that enhances Cucumber tables with three main methods: `#create!` for creating entities (ActiveRecord/FactoryGirl support), `#diff!` for comparing tables against HTML elements (table, dl, ul, form), and `#fill_in!` for form filling. It works by monkey-patching Cucumber's DataTable class.

## Development Commands

### Testing
- `rake spec` or `bundle exec rspec` - Run the full test suite
- `rspec spec/chop/table_spec.rb` - Run a specific test file
- `rspec spec/chop/table_spec.rb:42` - Run a specific test by line number

Note: RSpec is configured to run only tests marked with `focus: true`. When no focused tests exist, all tests run automatically.

### Development Setup
- `bin/setup` - Install dependencies after checkout
- `bin/console` - Interactive console for experimentation

### Multi-Version Testing
Tests must pass against Rails 7.0, 7.1, and 7.2 on Ruby 3.1, 3.2, and 3.3:
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
  - `Chop::DfnDl` - Definition list with `<dfn>` headings
  - `Chop::UnorderedList` - Unordered list (`<ul>`) diffing
  - `Chop::Form` - Form filling functionality

### Monkey-patching Strategy
The gem extends `Cucumber::MultilineArgument::DataTable` by prepending the DSL module, which adds the three main methods. The DSL module can also be called directly as `Chop.create!`, `Chop.diff!`, `Chop.fill_in!` to avoid monkey-patching entirely.

### Creation Strategies
Supports pluggable creation strategies via `Chop::Create.register_creation_strategy`:
- Default: ActiveRecord's `create!`
- FactoryGirl/FactoryBot support built-in
- Custom strategies can be registered

### Transformation DSL
The `#create!` method supports a rich DSL for transforming table data:
- **Field transformations**: `file`, `files`, `has_one`, `has_many`, `default`, `copy`, `rename`, `delete`
- **Low-level**: `field`, `transformation` for custom logic
- **Lifecycle hooks**: `after` for post-creation logic, `create` to override creation strategy

The `#diff!` method also supports transformations:
- **Capybara finders**: `rows`, `cells`, `text` to override default element selection
- **High-level transforms**: `image` to extract image filenames, `allow_not_found` for optional elements
- **Low-level**: `header`, `field`, `hash_transformation`, `transformation` for custom logic

### Diffing Architecture
Diffing works by:
1. Selecting HTML elements using Capybara finders (customizable via `rows`, `cells` blocks)
2. Extracting text content from those elements
3. Comparing against the expected table using `diff!` from Cucumber
4. Supporting element-specific extraction logic (e.g., images in table cells)

## Testing Patterns

- Uses RSpec with `spec_helper.rb` configuring focus filtering
- Tests organized by component in `spec/chop/` matching `lib/chop/` structure
- Tests cover both direct DSL calls and monkey-patched table behavior
- Uses Capybara for integration testing of diffing functionality with Cuprite headless browser