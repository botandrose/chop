require "active_support/core_ext/object/blank"
      
module Chop
  class UnorderedList < Struct.new(:selector, :table, :session, :block)
    def self.diff! selector, table, session: Capybara.current_session, &block
      new(selector, table, session, block).diff!
    end

    attr_accessor :transformations

    def initialize selector = "ul", table = nil, session = Capybara.current_session, block = nil, &other_block
      super
      self.transformations = []
      instance_eval &block if block.respond_to?(:call)
      instance_eval &other_block if block_given?
    end

    def base_to_a
      rows.collect do |row|
        row_to_text(row)
      end
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

    private

    def rows
      node.all("li")
    end

    def node
      @node ||= session.find(selector)
    end

    def row_to_text row
      [row].collect do |cell|
        text = cell.text
        if text.blank? and image = cell.all("img").first
          text = image["alt"]
        end
        text
      end
    end
  end

  Ul = UnorderedList
end

