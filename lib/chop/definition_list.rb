require "chop/diff"
      
module Chop
  class DefinitionList < Diff
    self.default_selector = "dl"
    self.rows_finder = ->(root) do
      root.all("dt,dd").slice_before do |node|
        node.tag_name == "dt"
      end
    end
    self.cells_finder = ->(row) { row }

    def column index, &block
      transformation do |rows|
        rows.map.with_index do |row, row_index|
          row[index] = block.call(row[index])
          row
        end
      end
    end
  end

  Dl = DefinitionList
end

