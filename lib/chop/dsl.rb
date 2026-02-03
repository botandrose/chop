require "active_support/inflector"

module Chop
  module DSL
    extend self

    def create! klass, table, &block
      Create.create! klass, table, &block
    end

    def diff! selector, table, session: Capybara.current_session, as: nil, timeout: nil, **kwargs, &block
      timeout ||= Capybara.default_max_wait_time
      class_name = if as
        as.to_s
      elsif selector.respond_to?(:tag_name)
        selector.tag_name
      else
        session.document.synchronize timeout, errors: session.driver.invalid_element_errors do
          session.find(selector).tag_name
        end
      end.camelize
      klass = const_get("Chop::#{class_name}")
      kwargs[:session] = session
      kwargs[:timeout] = timeout if timeout.present?
      klass.diff! selector, table, **kwargs, &block
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
