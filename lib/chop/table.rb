require "chop/base"

module Chop
  class Table < Base
    def default_selector
      "table"
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

    private

    def rows parent = nil
      node.all("#{parent} tr")
    end

    def cells row
      row.all(:xpath, "./*")
    end
  end
end

