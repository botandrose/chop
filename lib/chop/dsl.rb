require "active_support/inflector"

module Chop
  module DSL
    extend self

    def create! klass, table, &block
      Create.create! klass, table, &block
    end

    def diff! selector, table, session: Capybara.current_session, as: nil, timeout: nil, **kwargs, &block
      kwargs[:session] = session
      kwargs[:timeout] = timeout if timeout

      if as
        class_name = as.to_s.camelize
        klass = const_get("Chop::#{class_name}")
        klass.diff! selector, table, **kwargs, &block
      elsif selector.respond_to?(:tag_name)
        class_name = selector.tag_name.camelize
        klass = const_get("Chop::#{class_name}")
        klass.diff! selector, table, **kwargs, &block
      else
        effective_timeout = timeout || Capybara.default_max_wait_time
        errors = session.driver.invalid_element_errors + [Cucumber::MultilineArgument::DataTable::Different]
        Diff.synchronize_with_retry(session, effective_timeout, errors) do
          class_name = session.find(selector).tag_name.camelize
          klass = const_get("Chop::#{class_name}")
          klass.diff! selector, table, **kwargs, &block
        end
      end
    end

    def fill_in! table
      Form.fill_in! table
    end
  end

  if defined?(Cucumber::MultilineArgument::DataTable)
    Cucumber::MultilineArgument::DataTable.prepend Module.new {
      def create! klass, &block
        DSL.create! klass, self, &block
      end

      def diff! other_table="table", **kwargs, &block
        if other_table.respond_to?(:tag_name) || (other_table.is_a?(String) && !other_table.include?("|"))
          DSL.diff! other_table, self.dup, **kwargs, &block
        else
          super
        end
      end

      def fill_in!
        DSL.fill_in! self
      end
    }
  end
end

