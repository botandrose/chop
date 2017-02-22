module Chop
  module DSL
    def create! table, klass, &block
      Builder.build! table, klass, &block
    end

    def diff! table, selector, session: Capybara.current_session, &block
      class_name = session.find(selector).tag_name.capitalize
      klass = const_get("Chop::#{class_name}")
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

