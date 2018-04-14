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

    def field key
      transformation do |rows|
        rows.map do |row|
          if row.first.text.parameterize.underscore == key.to_s
            row[1] = yield(row[1])
          end
          row
        end
      end
    end

    def image *cols
      block = ->(cell){ cell_to_image_filename(cell) }
      cols.each do |col|
        method = col.is_a?(Symbol) ? :field : :column
        send method, col, &block
      end
    end
  end

  Dl = DefinitionList
end

