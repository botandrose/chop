require "chop/diff"
      
module Chop
  class DefinitionList < Diff
    self.default_selector = "dl"
    self.rows_finder = ->(root) { root.all("dfn") }
    self.cells_finder = ->(row) { row.all("dt,dd") }

    def column index, &block
      transformation do |rows|
        rows.map!.with_index do |row, row_index|
          row[index] = block.call(row[index])
          row
        end
      end
    end
  end

  Dl = DefinitionList
end

