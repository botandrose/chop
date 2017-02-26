require "chop/base"
      
module Chop
  class UnorderedList < Base
    def default_selector
      "ul"
    end

    private

    def rows
      node.all("li")
    end

    def cells row
      [row]
    end
  end

  Ul = UnorderedList
end

