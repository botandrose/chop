require "chop/definition_list"

module Chop
  class DfnDl < DefinitionList
    self.rows_finder = ->(root) do
      root.all("dfn")
    end

    self.cells_finder = ->(row) do
      row.all("dt,dd")
    end
  end
end

