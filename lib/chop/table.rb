require "active_support/core_ext/object/blank"

module Chop
  class Table < Struct.new(:selector, :table, :session, :block)
    def self.diff! selector, table, session: Capybara.current_session, &block
      new(selector, table, session, block).diff!
    end

    attr_accessor :transformations

    def initialize(selector = "table", table = nil, session = Capybara.current_session, block = nil, &other_block)
      super
      self.transformations = []
      instance_eval &block if block.respond_to?(:call)
      instance_eval &other_block if block_given?
    end

    def header_elements
      rows("thead")
    end

    def header
      header_elements.map do |row|
        row.all(:xpath, "./*").map(&:text)
      end
    end

    def body_elements
      rows("tbody")
    end

    def body
      body_elements.map do |row|
        row_to_text(row)
      end
    end

    def base_to_a
      header + body
    end

    def normalized_to_a
      raw = base_to_a
      max = raw.map(&:count).max
      raw.select { |row| row.count == max }
    end

    def to_a
      results = normalized_to_a
      transformations.each { |transformation| transformation.call(results) }
      results
    end

    def transformation &block
      transformations << block
    end

    def diff! cucumber_table = table
      cucumber_table.diff! to_a
    end

    def hashes
      rows = to_a.dup
      header = rows.shift
      rows.map do |row|
        Hash[header.zip(row)]
      end
    end

    def allow_not_found
      @allow_not_found = true
    end

    private

    def rows parent = nil
      node.all("#{parent} tr")
    end

    def node
      @node ||= begin
        session.find(selector)
      rescue Capybara::ElementNotFound
        raise unless @allow_not_found
        Capybara::Node::Simple.new("")
      end
    end

    def row_to_text row
      row.all(:xpath, "./*").map.with_index do |cell, index|
        cell_to_text cell, index
      end
    end

    def cell_to_text cell, index
      text = cell.text
      if text.blank? and image = cell.all("img").first
        text = image["alt"]
      end
      text
    end
  end
end

