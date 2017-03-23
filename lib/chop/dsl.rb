module Chop
  module DSL
    def create! klass, table, &block
      Create.create! klass, table, &block
    end

    def diff! selector, table, session: Capybara.current_session, &block
      class_name = session.find(selector).tag_name.capitalize
      klass = const_get("Chop::#{class_name}")
      klass.diff! selector, table, session: session, &block
    end

    def fill_in! table
      Form.fill_in! table
    end
  end
end

if defined?(Cucumber::MultilineArgument::DataTable)
  Cucumber::MultilineArgument::DataTable.prepend Module.new {
    def create! klass, &block
      Chop.create! klass, self, &block
    end

    def diff! other_table, options={}, &block
      if other_table.is_a?(String) && !other_table.include?("|")
        Chop.diff! other_table, self, &block
      else
        super
      end
    end

    def fill_in!
      Chop.fill_in! self
    end
  }
end

