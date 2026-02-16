require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/class/attribute"
require "active_support/hash_with_indifferent_access"
require "chop/config"
require "chop/regex_templates"

module Chop
  class Diff < Struct.new(:selector, :table, :session, :timeout, :block)
    def self.diff! selector, table, session: Capybara.current_session, timeout: Capybara.default_max_wait_time, atomic: Chop.atomic_diff, errors: [], **kwargs, &block
      errors += session.driver.invalid_element_errors
      errors += [Cucumber::MultilineArgument::DataTable::Different]
      session.document.synchronize timeout, errors: errors do
        instance = new(selector, table, session, timeout, block)
        instance.instance_variable_set(:@atomic, atomic)
        instance.diff! **kwargs
      end
    end

    def cell_to_image_filename cell
      cell.all("img", allow_reload: true).map do |img|
        File.basename(img[:src] || "").split("?")[0].sub(/-[0-9a-f]{64}/, '')
      end.first
    end

    class_attribute :default_selector, :rows_finder, :cells_finder, :text_finder

    self.rows_finder = -> { raise "Missing rows finder!" }
    self.cells_finder = -> { raise "Missing cells finder!" }
    self.text_finder = ->(cell) { cell.text }

    attr_accessor :header_transformations, :transformations

    attr_accessor :regex_templates_enabled, :regex_fields

    def initialize selector = nil, table = nil, session = Capybara.current_session, timeout = Capybara.default_max_wait_time, block = nil, &other_block
      super
      self.selector ||= default_selector
      self.header_transformations = []
      self.transformations = []
      instance_eval &block if block.respond_to?(:call)
      instance_eval &other_block if block_given?
    end

    def header_transformation &block
      header_transformations << block
    end

    def header index=nil, &block
      if index
        header_transformation do |row|
          if index.is_a?(Symbol)
            index = row.index do |cell|
              text_finder.call(cell).parameterize.underscore.to_sym == index
            end
          end
          row[index] = yield(row[index])
          row
        end
      else
        if block.arity.zero?
          @new_header = yield
        else
          header_transformation do |row|
            yield(row)
          end
        end
      end
    end

    def transformation &block
      transformations << block
    end

    # Enable embedded-regex templates within cells.
    # Optionally restrict application to specific fields (by header name or 1-based index).
    def regex *fields
      self.regex_templates_enabled = true
      self.regex_fields = fields unless fields.empty?
    end

    def hash_transformation &block
      transformation do |rows|
        header = rows[0]
        keys = header.to_a.map.with_index do |cell, index|
          key = cell.text.parameterize.underscore
          next key if key.present?
          next cell.text if cell.text.present?
          index + 1
        end
        body = rows[1..-1]
        hashes = body.map { |row| HashWithIndifferentAccess[keys.zip(row)] }
        yield hashes
        [header] + hashes.map(&:values)
      end
    end

    def field key
      hash_transformation do |hashes|
        hashes.map! do |row|
          row.merge key => yield(row[key])
        end
      end
    end

    def image *keys
      keys.each do |key|
        field(key) do |cell|
          cell_to_image_filename(cell)
        end
      end
    end

    def rows &block
      self.rows_finder = block
    end

    def cells &block
      self.cells_finder = block
    end

    def text &block
      self.text_finder = block
    end

    def allow_not_found
      @allow_not_found = true
    end

    def to_a
      rows = rows_finder.call(root).map { |row| cells_finder.call(row).to_a }
      rows = normalize(rows)

      header = @new_header ? normalize([@new_header]).first : rows.shift || []
      header = header_transformations.reduce(header) do |header, transformation|
        header = transformation.call(header)
        normalize([header]).first
      end

      if header
        rows = [header] + rows
        rows = normalize(rows)
      end

      rows = transformations.reduce(rows) do |rows, transformation|
        rows = transformation.call(rows)
        normalize(rows)
      end

      rows.map do |row|
        row.map do |cell|
          text = text_finder.call(cell)
          @atomic && text.is_a?(String) ? normalize_atomic_text(text) : text
        end
      end
    end

    def diff! cucumber_table = table, **kwargs
      actual = to_a
      # FIXME should just delegate to Cucumber's #diff!. Cucumber needs to handle empty tables better.
      if !cucumber_table.raw.flatten.empty? && !actual.flatten.empty?
        if regex_templates_enabled
          cucumber_table = Chop::RegexTemplates.apply(cucumber_table, actual, regex_fields)
        end
        cucumber_table.diff! actual, **kwargs
      elsif cucumber_table.raw.flatten != actual.flatten
        raise Cucumber::MultilineArgument::DataTable::Different.new(cucumber_table)
      end
    end

    private

    def normalize rows
      max = rows.map(&:count).max
      rows.map do |row|
        row.to_a << "" while row.length < max
        row.map { |cell| Node(cell) }
      end
    end

    # Normalize text from a Nokogiri snapshot to match what Capybara drivers
    # return from visible_text. Replicates Capybara::Node::WhitespaceNormalizer#normalize_spacing.
    def normalize_atomic_text(text)
      text
        .delete("\u200b\u200e\u200f")
        .tr(" \n\f\t\v\u2028\u2029", " ")
        .squeeze(" ")
        .sub(/\A[[:space:]&&[^\u00a0]]+/, "")
        .sub(/[[:space:]&&[^\u00a0]]+\z/, "")
        .tr("\u00a0", " ")
    end

    def root
      @root ||= begin
        element = if selector.is_a?(Capybara::Node::Element)
          selector
        else
          session.find(selector, wait: timeout)
        end
        if @atomic
          html = element["outerHTML"] || element.native.to_html
          Node(html)
        else
          element
        end
      rescue Capybara::ElementNotFound
        raise unless @allow_not_found
        Node("")
      end
    end

    def Node value
      if value.respond_to?(:text)
        value
      else
        Capybara::Node::Simple.new(value.to_s)
      end
    end
  end
end
