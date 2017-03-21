require "chop/diff"
      
module Chop
  class DefinitionList < Diff
    self.default_selector = "dl"
    self.rows_finder = ->(root) { root.all("dfn") }
    self.cells_finder = ->(row) { row.all("dt,dd") }

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
  end

  Dl = DefinitionList
end

