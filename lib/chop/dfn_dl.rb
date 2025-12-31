require "chop/definition_list"

module Chop
  class DfnDl < DefinitionList
    self.rows_finder = ->(root) do
      root.all("dfn", allow_reload: true)
    end

    self.cells_finder = ->(row) do
      row.all("dt,dd", allow_reload: true)
    end
  end
end

