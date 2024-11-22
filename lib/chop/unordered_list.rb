require "chop/definition_list"
      
module Chop
  class UnorderedList < DefinitionList
    self.default_selector = "ul"
    self.rows_finder = ->(root) { root.all("li") }
    self.cells_finder = ->(row) { [row] }

    def nested
      self.rows_finder = ->(root) {
        recurse_tree [], root
      }
      self.text_finder = ->(cell) {
        cell.chop_prefix + cell.all(:xpath, "*[not(self::ul)]").map(&:text).join(" ").strip
      }
    end

    private

    def recurse_tree structure, root, prefix: "- "
      root.all(:xpath, "./li").each do |li|
        li.define_singleton_method(:chop_prefix) { prefix }
        structure << li

        if li.has_xpath?("./ul")
          root = li.find(:xpath, "./ul")
          structure = recurse_tree(structure, root, prefix: prefix + "  ")
        end
      end
      structure
    end
  end

  Ul = UnorderedList
end

