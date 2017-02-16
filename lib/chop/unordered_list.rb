require "delegate"
      
module Chop
  class UnorderedList < SimpleDelegator
    def self.diff! table, &block
      new.diff! table
    end

    def initialize selector = "ul", session: Capybara.current_session
      super(session)
      @selector = selector
    end

    def to_a
      rows.collect do |row|
        row_to_text(row)
      end
    end

    def normalized_to_a
      raw = to_a
      max = raw.map(&:count).max
      raw.select { |row| row.count == max }
    end

    def diff! table
      table.diff! normalized_to_a
    end

    private

    def rows
      node.all("li")
    end

    def node
      @node ||= find(@selector)
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
end

