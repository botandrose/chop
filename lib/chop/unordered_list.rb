require "chop/base"
      
module Chop
  class UnorderedList < Base
    private

    def default_selector
      "ul"
    end

    def default_rows_finder
      Proc.new do |root|
        root.all("li")
      end
    end

    def default_cells_finder
      Proc.new do |row|
        [row]
      end
    end
  end

  Ul = UnorderedList
end

