require "chop/version"
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

    def empty.diff!(...)
      super
    rescue Capybara::ElementNotFound
    end

    empty
  end
end

