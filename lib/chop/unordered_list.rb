require "chop/diff"
      
module Chop
  class UnorderedList < Diff
    self.default_selector = "ul"
    self.rows_finder = ->(root) { root.all("li") }
    self.cells_finder = ->(row) { [row] }
  end

  Ul = UnorderedList
end

