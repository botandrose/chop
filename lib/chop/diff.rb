require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/class/attribute"
require "active_support/hash_with_indifferent_access"

module Chop
  class Diff < Struct.new(:selector, :table, :session, :timeout, :block)
    def self.diff! selector, table, session: Capybara.current_session, timeout: Capybara.default_max_wait_time, errors: [], **kwargs, &block
      errors += session.driver.invalid_element_errors
      errors += [Cucumber::MultilineArgument::DataTable::Different]
      session.document.synchronize timeout, errors: errors do
        new(selector, table, session, timeout, block).diff! **kwargs
      end
    end

    def cell_to_image_filename cell
      cell.all("img").map do |img|
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
        row.map { |cell| text_finder.call(cell) }
      end
    end

    def diff! cucumber_table = table, **kwargs
      actual = to_a
      # FIXME should just delegate to Cucumber's #diff!. Cucumber needs to handle empty tables better.
      if !cucumber_table.raw.flatten.empty? && !actual.flatten.empty?
        if regex_templates_enabled
          cucumber_table = apply_regex_templates(cucumber_table, actual)
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

    def root
      @root ||= begin
        if selector.is_a?(Capybara::Node::Element)
          selector
        else
          session.find(selector, wait: timeout)
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

    TOKEN = /
      (?<!\\)            # not preceded by backslash
      \#\{               # start of token
      \/                 # opening slash
      (.*?)              # pattern (non-greedy)
      \/                 # closing slash
      ([imx]*)           # optional flags
      \}                 # end of token
    /mx

    def apply_regex_templates(cucumber_table, actual)
      allowed_columns = resolve_regex_allowed_columns(actual)

      expected = cucumber_table.raw.map.with_index do |row, i|
        row.map.with_index do |cell, j|
          str = cell.to_s
          # Always de-escape literal token markers so \#{/.../} becomes literal text
          deescaped = str.gsub('\\#{', '#{')

          if apply_regex_for_column?(allowed_columns, j) && deescaped.match?(TOKEN)
            built = build_template_regex(deescaped)
            actual_cell = (actual.dig(i, j) || "").to_s
            if built[:regex].match?(actual_cell)
              actual_cell
            else
              deescaped
            end
          else
            deescaped
          end
        end
      end

      Cucumber::MultilineArgument::DataTable.from(expected)
    end

    def resolve_regex_allowed_columns(actual)
      return :all if regex_fields.nil? || regex_fields.empty?

      idxs = []

      # Integer fields are 1-based indices
      regex_fields.each do |f|
        if f.is_a?(Integer)
          idxs << (f - 1)
        end
      end

      # Symbol/String fields are header names (use first row of actual)
      names = regex_fields.select { |f| f.is_a?(Symbol) || f.is_a?(String) }.map(&:to_s)
      if names.any? && actual.first
        header = actual.first
        header_keys = header.map.with_index do |cell, index|
          text = cell.to_s
          key = text.parameterize.underscore
          key = text if key.blank? && text.present?
          key = (index + 1).to_s if key.blank?
          key
        end
        normalized_names = names.map { |n| n.to_s.parameterize.underscore }
        header_keys.each_with_index do |key, idx|
          idxs << idx if normalized_names.include?(key)
        end
      end

      idxs.uniq
    end

    def apply_regex_for_column?(allowed_columns, j)
      return true if allowed_columns == :all
      allowed_columns.include?(j)
    end

    def build_template_regex(str)
      parts = []
      last = 0
      flags = "".dup

      str.to_enum(:scan, TOKEN).each do
        m = Regexp.last_match
        literal = str[last...m.begin(0)]
        parts << Regexp.escape(literal)
        pattern, f = m.captures
        flags << f
        parts << "(?:#{pattern})"
        last = m.end(0)
      end

      tail = str[last..-1] || ""
      parts << Regexp.escape(tail)

      options = 0
      options |= Regexp::IGNORECASE if flags.include?("i")
      options |= Regexp::MULTILINE  if flags.include?("m")
      options |= Regexp::EXTENDED   if flags.include?("x")

      regex = Regexp.new("\\A(?:#{parts.join})\\z", options)
      { regex: regex }
    end
  end
end
