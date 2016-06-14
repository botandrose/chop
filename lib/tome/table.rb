require "delegate"
      
module Tome
  class Table < SimpleDelegator
    def initialize selector = "table", session: Capybara.current_session
      super(session)
      @selector = selector
    end

    def header_elements
      rows("thead")
    end

    def header
      header_elements.collect do |row|
        row_to_text(row)
      end
    end

    def body_elements
      rows("tbody")
    end

    def body
      body_elements.collect do |row|
        row_to_text(row)
      end
    end

    def to_a
      header + body
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

    def rows parent = nil
      node.all("#{parent} tr")
    end

    def node
      @node ||= find(@selector)
    end

    def row_to_text row
      row.all(:xpath, "./*").collect do |cell|
        text = cell.text
        if text.blank? and image = cell.all("img").first
          text = image["alt"]
        end
        text
      end
    end
  end
end

