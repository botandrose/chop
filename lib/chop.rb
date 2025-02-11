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
    empty = table([[]])

    def empty.diff! other_table, **kwargs, &block
      if other_table.is_a?(String)
        begin
          other_table = Capybara.current_session.find(other_table)
        rescue Capybara::ElementNotFound
          return
        end
      end
      super other_table, **kwargs.reverse_merge(surplus_col: true, surplus_row: true), &block
    end

    empty
  end

  def self.table(raw)
    Cucumber::MultilineArgument::DataTable.from(raw)
  end
end

