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
          kwargs[:as] ||= Capybara.current_session.find(other_table).tag_name
        rescue Capybara::ElementNotFound
          return
        end
        user_block = block
        block = proc do
          allow_not_found
          instance_eval &user_block if user_block
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

