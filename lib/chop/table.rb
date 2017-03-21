require "chop/base"

module Chop
  class Table < Base
    self.default_selector = "table"
    self.rows_finder = ->(root) { root.all("tr") }
    self.cells_finder = ->(row) { row.all("td,th") }
  end
end

