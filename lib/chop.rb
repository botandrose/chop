require "chop/version"
require "cucumber"
require "chop/create"
require "chop/table"
require "chop/definition_list"
require "chop/dfn_dl"
require "chop/unordered_list"
require "chop/form"
require "chop/dsl"
require "chop/config"

module Chop
  extend DSL
  extend Config

  def self.empty_table
    empty = Cucumber::MultilineArgument::DataTable.from([[]])

    def empty.diff! other_table, **kwargs, &block
      super other_table, **kwargs.reverse_merge(surplus_col: true, surplus_row: true), &block
    rescue Capybara::ElementNotFound
    end

    empty
  end
end

