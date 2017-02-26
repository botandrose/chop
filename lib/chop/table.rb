require "chop/base"

module Chop
  class Table < Base
    private

    def default_selector
      "table"
    end

    def default_rows_finder
      Proc.new do |root|
        root.all("tr")
      end
    end

    def default_cells_finder
      Proc.new do |row|
        row.all("td,th")
      end
    end
  end
end

