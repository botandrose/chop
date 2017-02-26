require "chop/base"
      
module Chop
  class DefinitionList < Base
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

    def default_selector
      "dl"
    end

    def default_rows_finder
      Proc.new do |root|
        root.all("dfn")
      end
    end

    def default_cells_finder
      Proc.new do |row|
        row.all("dt,dd")
      end
    end
  end

  Dl = DefinitionList
end

