require "active_support/core_ext/object/blank"
require "active_support/core_ext/class/subclasses"

module Chop
  class Form < Struct.new(:table, :session, :path)
    def self.fill_in! table, session: Capybara.current_session, path: "features/support/fixtures"
      new(table, session, path).fill_in!
    end

    def self.diff! selector, table, session: Capybara.current_session, &block
      all_fields = session.find("form").all("input, textarea, select")
      relevant_fields = all_fields.inject([]) do |fields, field|
        next fields if field[:name].blank?
        next fields if field[:type] == "submit"
        fields + [field]
      end
      deduplicated_fields = relevant_fields.inject([]) do |fields, field|
        next fields if fields.map { |field| field[:name] }.include?(field[:name])
        fields + [field]
      end
      actual = deduplicated_fields.inject([]) do |fields, field|
        next fields unless label = find_label_for(field)
        field = Field.from(session, field)
        fields + [[label.text, field.get_value]]
      end
      table.diff! actual, surplus_row: false
    end

    def self.find_label_for field, session: Capybara.current_session
      if field[:id].present?
        session.first("label[for='#{field[:id]}']")
      else
        raise "cannot find label without id... yet"
      end
    end

    def fill_in!
      table.rows_hash.each do |label, value|
        Field.for(session, label, value, path).fill_in!
      end
    end

    class Field < Struct.new(:session, :label, :value, :path, :field)
      def self.for session, label, value, path
        field = session.find_field(label)
        candidates.map do |klass|
          klass.new(session, label, value, path, field)
        end.find(&:matches?)
      end

      def self.from session, field
        candidates.map do |klass|
          klass.new(session, nil, nil, nil, field)
        end.find(&:matches?)
      end

      def self.candidates
        descendants.sort_by do |a|
          a == Chop::Form::Default ? 1 : -1 # ensure Default comes last
        end
      end

      def get_value
        field.value
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
          checkbox.set checkbox_label_in_values?(checkbox)
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
        field.set value.present?
      end

      def get_value
        field.checked? ? "✓" : ""
      end
    end

    class Radio < Field
      def matches?
        field[:type] == "radio"
      end

      def fill_in!
        if nonstandard_labelling?
          value_field.click
        else
          session.choose label
        end
      end

      def get_value
        session.all("[name='#{field[:name]}']").find(&:checked?).try(:value)
      end

      private

      def nonstandard_labelling?
        value_field[:name] == field[:name]
      end

      def value_field
        session.first("[name='#{field[:name]}'][value='#{value}']")
      rescue Capybara::ElementNotFound
        {}
      end
    end

    class SingleFile < Field
      def matches?
        field[:type] == "file" && !field[:multiple]
      end

      def fill_in!
        assert_single_file!
        field.set file_path
      end

      private

      def file_path
        ::File.expand_path(::File.join(path, value)).tap do |path|
          ::File.open(path){} # raise Errno::ENOENT if file doesn't exist
        end
      end

      def assert_single_file!
        if value.include?(" ")
          raise TypeError.new("Cannot attach multiple files to file field '#{label}' without the multiple attribute present")
        end
      end
    end

    class MultipleFile < Field
      def matches?
        field[:type] == "file" && field[:multiple]
      end

      def fill_in!
        field.set file_paths
      end

      private

      def file_paths
        value.split(" ").map do |filename|
          ::File.expand_path(::File.join(path, filename)).tap do |path|
            ::File.open(path){} # raise Errno::ENOENT if file doesn't exist
          end
        end
      end
    end

    class Default < Field
      def matches?
        true
      end

      def fill_in!
        field.set value
      end
    end
  end
end
