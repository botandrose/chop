require "active_support/core_ext/object/blank"
require "active_support/core_ext/class/subclasses"

module Chop
  class Form < Struct.new(:table, :session, :path)
    def self.fill_in! table, session: Capybara.current_session, path: "features/support/fixtures"
      new(table, session, path).fill_in!
    end

    def self.diff! selector, table, session: Capybara.current_session, &block
      root = begin
        if selector.is_a?(Capybara::Node::Element)
          selector
        else
          session.find(selector)
        end
      rescue Capybara::ElementNotFound
        raise unless @allow_not_found
        Node("")
      end

      actual = root.all(Field.combined_css_selector)
        .filter_map { |field_element| Field.from(session, field_element) }
        .select(&:should_include_in_diff?)
        .uniq { |field| field.field[:name] }
        .filter_map(&:to_diff_row)

      block.call(actual, root) if block_given?
      table.diff! actual, surplus_row: false, misplaced_col: false
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

      def self.css_selector
        "input"
      end

      def self.combined_css_selector
        candidates.map(&:css_selector).uniq.join(", ")
      end

      def get_value
        field.value
      end

      def should_include_in_diff?
        field[:name].present? &&
          field[:type] != "submit" &&
          field[:type] != "hidden"
      end

      def label_text
        return nil unless field[:id].present?
        label_element = session.first("label[for='#{field[:id]}']", visible: :all, minimum: 0, wait: 0.1)
        label_element&.text(:all)
      end

      def to_diff_row
        return nil unless label = label_text
        [label, diff_value]
      end

      def diff_value
        get_value.to_s
      end

      def fill_in!
        field.set value
      end
    end

    class MultipleSelect < Field
      def self.css_selector
        "select"
      end

      def matches?
        field.tag_name == "select" && field[:multiple].to_s == "true"
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
      def self.css_selector
        "select"
      end

      def matches?
        field.tag_name == "select" && field[:multiple].to_s == "false"
      end

      def fill_in!
        session.select value, from: label
      end

      def get_value
        if selected_value = field.value
          field.find("option[value='#{selected_value}']").text
        end
      end

      def diff_value
        get_value.to_s
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

      def get_value
        checkboxes.select(&:checked?).map(&:value).join(", ")
      end

      def diff_value
        get_value
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

      def diff_value
        get_value
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
        session.all(:field, value).select { |el| el[:name] == field[:name] }.last || {}
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
        return nil unless value.present?
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
          next nil unless filename.present?
          ::File.expand_path(::File.join(path, filename)).tap do |path|
            ::File.open(path){} # raise Errno::ENOENT if file doesn't exist
          end
        end.compact
      end
    end

    class ViaJavascript < Field
      def matches?
        %w[time week month range].include?(field[:type])
      end

      def fill_in!
        session.execute_script("document.getElementById('#{field[:id]}').value = '#{value}'")
      end
    end

    class Textarea < Field
      def self.css_selector
        "textarea"
      end

      def matches?
        field.tag_name == "textarea"
      end
    end

    class Default < Field
      def matches?
        true
      end
    end
  end
end
