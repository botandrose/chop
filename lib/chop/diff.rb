require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/class/attribute"

module Chop
  class Diff < Struct.new(:selector, :table, :session, :block)
    def self.diff! selector, table, session: Capybara.current_session, &block
      new(selector, table, session, block).diff!
    end

    class_attribute :default_selector, :rows_finder, :cells_finder, :text_finder

    self.rows_finder = -> { raise "Missing rows finder!" }
    self.cells_finder = -> { raise "Missing cells finder!" }
    self.text_finder = ->(cell) { cell.text }

    def self.text_or_image_alt_finder
      ->(cell) do
        text = cell.text
        if text.blank? && image = cell.first("img")
          image["alt"]
        else
          text
        end
      end
    end

    attr_accessor :header_transformations, :transformations

    def initialize selector = nil, table = nil, session = Capybara.current_session, block = nil, &other_block
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
        end
      else
        if block.arity.zero?
          @new_header = yield
        else
          header_transformation do |row|
            row.replace yield(row)
          end
        end
      end
    end

    def transformation &block
      transformations << block
    end

    def hash_transformation &block
      transformation do |rows|
        header = rows[0]
        keys = header.to_a.map { |cell| cell.text.parameterize.underscore.to_sym }
        body = rows[1..-1]
        hashes = body.map { |row| Hash[keys.zip(row)] }
        yield hashes
        rows.replace [header] + hashes.map(&:values)
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
          if image = cell.first("img")
            image["alt"]
          else
            cell
          end
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
      header_transformations.each do |transformation|
        transformation.call(header)
        header = normalize([header]).first
      end

      if header
        rows = [header] + rows
        rows = normalize(rows)
      end

      transformations.each do |transformation|
        transformation.call(rows)
        rows = normalize(rows)
      end

      rows.map do |row|
        row.map { |cell| text_finder.call(cell) }
      end
    end

    def diff! cucumber_table = table
      actual = to_a
      # FIXME should just delegate to Cucumber's #diff!. Cucumber needs to handle empty tables better.
      if !cucumber_table.raw.flatten.empty? && !actual.flatten.empty?
        cucumber_table.diff! actual
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
        session.find(selector)
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
