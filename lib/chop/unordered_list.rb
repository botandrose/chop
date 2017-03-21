require "chop/base"
      
module Chop
  class UnorderedList < Base
    self.default_selector = "ul"
    self.rows_finder = ->(root) { root.all("li") }
    self.cells_finder = ->(row) { [row] }
  end

  Ul = UnorderedList
end

