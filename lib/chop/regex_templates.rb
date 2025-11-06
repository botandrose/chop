module Chop
  module RegexTemplates
    TOKEN = /
      (?<!\\)       # not preceded by backslash
      \#\{          # start of token
      \/            # opening slash
      (.*?)         # pattern (non-greedy)
      \/            # closing slash
      ([imx]*)      # optional flags
      \}            # end of token
    /mx

    module_function

    def apply(cucumber_table, actual, fields)
      allowed_columns = columns_for(fields, cucumber_table.raw.first)

      expected = cucumber_table.raw.map.with_index do |row, i|
        row.map.with_index do |cell, j|
          str = cell.to_s
          # De-escape literal token markers so \#{/.../} becomes literal '#{...}'
          deescaped = str.gsub('\\#{', '#{')

          if allowed?(allowed_columns, j) && deescaped.include?('#{') && deescaped.match?(TOKEN)
            regex = expand_template(deescaped)
            actual_cell = (actual.dig(i, j) || "").to_s
            if regex.match?(actual_cell)
              actual_cell
            else
              deescaped
            end
          else
            deescaped
          end
        end
      end

      Cucumber::MultilineArgument::DataTable.from(expected)
    end

    def columns_for(fields, expected_header)
      return :all if fields.nil? || fields.empty?

      idxs = []

      fields.each do |f|
        case f
        when Integer
          idxs << (f - 1)
        when Symbol, String
          next unless expected_header
          normalized = f.to_s.parameterize.underscore
          header_keys = expected_header.map.with_index do |text, idx|
            t = text.to_s
            key = t.parameterize.underscore
            key = t if key.blank? && t.present?
            key = (idx + 1).to_s if key.blank?
            key
          end
          header_keys.each_with_index do |key, idx|
            idxs << idx if key == normalized
          end
        end
      end

      idxs.uniq
    end

    def allowed?(allowed_columns, j)
      return true if allowed_columns == :all
      allowed_columns.include?(j)
    end

    def expand_template(str)
      parts = []
      last = 0

      str.to_enum(:scan, TOKEN).each do
        m = Regexp.last_match
        literal = str[last...m.begin(0)]
        parts << Regexp.escape(literal)
        pattern, flags = m.captures
        if flags.to_s.empty?
          parts << "(?:#{pattern})"
        else
          parts << "(?#{flags}:#{pattern})"
        end
        last = m.end(0)
      end

      tail = str[last..-1] || ""
      parts << Regexp.escape(tail)

      Regexp.new("\\A(?:#{parts.join})\\z")
    end
  end
end
