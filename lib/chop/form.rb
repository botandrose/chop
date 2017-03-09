require "active_support/core_ext/object/blank"
require "active_support/core_ext/class/subclasses"

module Chop
  class Form < Struct.new(:table, :session, :path)
    def self.fill_in! table, session: Capybara.current_session, path: "features/support/fixtures"
      new(table, session, path).fill_in!
    end

    def fill_in!
      table.rows_hash.each do |label, value|
        Field.for(session, label, value, path).fill_in!
      end
    end

    class Field < Struct.new(:session, :label, :value, :path)
      def self.for *args
        descendants.map do |klass|
          klass.new(*args)
        end.find(&:matches?)
      end

      private

      def field
        @field ||= session.find_field(label)
      end
    end

    class MultipleSelect < Field
      def matches?
        field.tag_name == "select" && field[:multiple]
      end

      def fill_in!
        field.all("option").map(&:text).each do |value|
          session.unselect value, from: label
        end
        value.split(", ").each do |value|
          session.select value, from: label
        end
      end
    end

    class Select < Field
      def matches?
        field.tag_name == "select" && !field[:multiple]
      end

      def fill_in!
        session.select value, from: label
      end
    end

    class MultipleCheckbox < Field
      def matches?
        field[:type] == "checkbox" && field[:name].to_s.end_with?("[]")
      end

      def fill_in!
        checkboxes.each do |checkbox|
          if checkbox_label_in_values? checkbox
            session.check(checkbox[:id])
          else
            session.uncheck(checkbox[:id])
          end
        end
      end

      private

      def checkboxes
        session.all("[name='#{field[:name]}']")
      end

      def checkbox_label_in_values? checkbox
        values = value.split(", ")
        labels = session.all("label[for='#{checkbox[:id]}']").map(&:text)
        (values & labels).any?
      end
    end

    class Checkbox < Field
      def matches?
        field[:type] == "checkbox" && !field[:name].to_s.end_with?("[]")
      end

      def fill_in!
        if value.present?
          session.check label
        else
          session.uncheck label
        end
      end
    end

    class Radio < Field
      def matches?
        field[:type] == "radio"
      end

      def fill_in!
        if nonstandard_labelling?
          session.choose value
        else
          session.choose label
        end
      end

      private

      def nonstandard_labelling?
        value_field[:name] == field[:name]
      end

      def value_field
        session.find_field(value)
      rescue Capybara::ElementNotFound
        {}
      end
    end

    class File < Field
      def matches?
        field[:type] == "file"
      end

      def fill_in!
        session.attach_file label, ::File.join(path, value)
      end
    end

    class Default < Field
      def matches?
        true
      end

      def fill_in!
        session.fill_in label, with: value
      end
    end
  end
end
