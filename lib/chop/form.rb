module Chop
  class Form < Struct.new(:table, :session)
    def self.fill_in! table, session: Capybara.current_session
      new(table, session).fill_in!
    end

    def fill_in!
      table.rows_hash.each do |label, value|
        field = session.find_field(label)
        if field.tag_name == "select"
          session.select value, from: label
        elsif field[:type] == "file"
          session.attach_file label, "features/support/fixtures/#{value}"
        else
          session.fill_in label, with: value
        end
      end
    end
  end
end
