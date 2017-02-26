require "active_support/core_ext/object/blank"

module Chop
  class Base < Struct.new(:selector, :table, :session, :block)
    def self.diff! selector, table, session: Capybara.current_session, &block
      new(selector, table, session, block).diff!
    end

    attr_accessor :transformations

    def initialize selector = nil, table = nil, session = Capybara.current_session, block = nil, &other_block
      super
      self.selector ||= default_selector
      self.transformations = []
      instance_eval &block if block.respond_to?(:call)
      instance_eval &other_block if block_given?
    end

    def transformation &block
      transformations << block
    end

    def base_to_a
      rows.collect do |row|
        row_to_text(row)
      end
    end

    def normalize
      transformation do |raw|
        max = raw.map(&:count).max
        raw.map! do |row|
          row << "" while row.length < max
          row
        end
      end
    end

    def to_a
      results = base_to_a
      normalize
      transformations.each { |transformation| transformation.call(results) }
      results
    end

    def diff! cucumber_table = table
      cucumber_table.diff! to_a
    end

    def allow_not_found
      @allow_not_found = true
    end

    def hashes
      rows = to_a.dup
      header = rows.shift
      rows.map do |row|
        Hash[header.zip(row)]
      end
    end

    private

    def node
      @node ||= begin
        session.find(selector)
      rescue Capybara::ElementNotFound
        raise unless @allow_not_found
        Capybara::Node::Simple.new("")
      end
    end

    def row_to_text row
      cells(row).map do |cell|
        cell_to_text(cell)
      end
    end

    def cell_to_text cell
      text = cell.text
      if text.blank? and image = cell.all("img").first
        text = image["alt"]
      end
      text
    end
  end
end
