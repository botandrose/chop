require "chop/diff"

module Chop
  class Table < Diff
    self.default_selector = "table"
    self.rows_finder = ->(root) { root.all("tr", allow_reload: true) }
    self.cells_finder = ->(row) { row.all("td,th", allow_reload: true) }
  end
end

