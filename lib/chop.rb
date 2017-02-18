require "chop/version"
require "chop/builder"
require "chop/table"
require "chop/definition_list"
require "chop/unordered_list"

module Chop
  class << self
    def create! table, klass, &block
      Builder.build! table, klass, &block
    end

    def diff! table, selector, &block
      class_name = Capybara.current_session.find(selector).tag_name.capitalize
      klass = const_get(class_name)
      klass.diff! table, &block
    end
  end
end

if defined?(Cucumber::MultilineArgument::DataTable)
  Cucumber::MultilineArgument::DataTable.prepend Module.new {
    def create! klass, &block
      Chop.create! self, klass, &block
    end

    def diff! other_table, options={}, &block
      if other_table.is_a?(String) && !other_table.include?("|")
        Chop.diff! self, other_table, &block
      else
        super
      end
    end
  }
end

