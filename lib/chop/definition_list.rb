require "active_support/core_ext/object/blank"
      
module Chop
  class DefinitionList < Struct.new(:selector, :table, :session, :block)
    def self.diff! selector, table, session: Capybara.current_session, &block
      new(selector, table, session, block).diff!
    end

    attr_accessor :transformations

    def initialize selector = "dl", table = nil, session = Capybara.current_session, block = nil, &other_block
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
      raw.map do |row|
        row << "" while row.length < max
        row
      end
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

    def column index, &block
      transformation do |raw|
        raw.map!.with_index do |row, row_index|
          row_element = rows[row_index]
          cell_element = cells(row_element)[index]
          row[index] = block.call(row[index], cell_element, row_element)
          row
        end
      end
    end

    def header &block
      transformation do |raw|
        new_header = block.call(raw)
        new_header << "" while new_header.length < (raw.first.try(:length) || 0)
        raw.unshift new_header
        raw
      end
    end

    private

    def rows
      node.all("dfn")
    end

    def node
      @node ||= session.find(selector)
    end

    def row_to_text row
      cells(row).map do |cell|
        cell_to_text(cell)
      end
    end

    def cells row
      row.all("dt,dd")
    end

    def cell_to_text cell
      text = cell.text
      if text.blank? and image = cell.all("img").first
        text = image["alt"]
      end
      text
    end
  end

  Dl = DefinitionList
end

