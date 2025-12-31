require "spec_helper"
require "chop/table"
require "cucumber"
require "capybara"
require "puma"
require "slim"

describe Chop::Table do
  let(:app) do
    Proc.new { [200, {"Content-Type" => "text/html"}, [body]] }
  end

  before do
    Capybara.app = app
    Capybara.server = :puma, { Silent: true }
    Capybara.current_session.visit("/")
  end

  describe ".diff!" do
    context "with a header" do
      let(:body) do
        slim """
          table
            thead
              tr: th A
            tbody
              tr: td 1
              tr: td 2
        """
      end

      let(:table) do
        [
          ["A"],
          ["1"],
          ["2"],
        ]
      end

      it "converts the selector to a table and diffs it with the supplied table" do
        described_class.diff! "table", table_from(table)
      end

      it "fails the diff when the tables are different" do
        expect {
          described_class.diff! "table", table_from([[]])
        }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
      end
    end

    context "without a header" do
      let(:body) do
        slim """
          table
            tr: th A
            tr: td 1
            tr: td 2
        """
      end

      let(:table) do
        [
          ["A"],
          ["1"],
          ["2"],
        ]
      end

      it "converts the selector to a table and diffs it with the supplied table" do
        described_class.diff! "table", table_from(table)
      end

      it "fails the diff when the tables are different" do
        expect {
          described_class.diff! "table", table_from([[]])
        }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
      end
    end

    context "with different row lengths" do
      let(:body) do
        slim """
          table
            thead
              tr
                th A
                th B
            tbody
              tr
                td 1
              tr
                td 2
        """
      end

      let(:table) do
        [
          ["A", "B"],
          ["1", ""],
          ["2", ""],
        ]
      end

      it "normalizes the table" do
        described_class.diff! "table", table_from(table)
      end
    end

    context "with empty table" do
      let(:body) do
        slim """
          table
            thead
              tr
                th A
                th B
            tbody
              tr
                td 1
              tr
                td 2
        """
      end

      let(:table) do
        [
          ["A", "B"],
          ["1", ""],
          ["2", ""],
        ]
      end

      it "is cool with diffing a non-existent table" do
        described_class.diff! "#doesnt_exist", table_from([[]]) do
          allow_not_found
        end
      end

      it "fails the diff when a non-existent table is found" do
        expect {
          described_class.diff! "table", table_from([[]]) do
            allow_not_found
          end
        }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
      end

      it "fails the diff when a non-existent table should be present" do
        expect {
          described_class.diff! "#doesnt_exist", table_from(table) do
            allow_not_found
          end
        }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
      end

      it "is cool with diffing an empty table" do
        described_class.diff! "table", table_from([[]]) do
          rows do |root|
            root.all("tfoot tr")
          end
        end
      end

      it "fails the diff when a empty table is present" do
        expect {
          described_class.diff! "table", table_from([[]])
        }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
      end

      it "fails the diff when a empty table should be present" do
        expect {
          described_class.diff! "#doesnt_exist", table_from(table) do
            allow_not_found
          end
        }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
      end
    end

    context "with capybara element" do
      let(:body) do
        slim """
          table
            thead
              tr: th A
            tbody
              tr: td 1
              tr: td 2
        """
      end

      let(:table) do
        [
          ["A"],
          ["1"],
          ["2"],
        ]
      end

      it "accepts a capybara element as the first argument" do
        element = Capybara.current_session.find("table")
        described_class.diff! element, table_from(table)
      end

      it "accepts timeout option and it down to capybara finder" do
        element = Capybara.current_session.find("table")
        expect(Capybara.current_session).to receive(:find).with("table", wait: 30).and_return(element)
        described_class.diff! "table", table_from(table), timeout: 30
      end
    end
  end

  describe "block methods" do
    let(:body) do
      slim """
        table
          thead
            tr: th
              span> A
              span> B
          tbody
            tr: td
              span> 1
              span> 2
            tr: td
              span> 2
              span> 3
      """
    end

    describe "#rows" do
      let(:table) do
        [
          ["1 2"],
          ["2 3"],
        ]
      end

      it "overrides existing default row finder" do
        described_class.diff! "table", table_from(table) do
          rows do |root|
            root.all("tbody tr")
          end
        end
      end
    end

    describe "#cells" do
      let(:table) do
        [
          ["A","B"],
          ["1","2"],
          ["2","3"],
        ]
      end

      it "overrides existing default cell finder" do
        described_class.diff! "table", table_from(table) do
          cells do |row|
            row.all("th span, td span")
          end
        end
      end
    end

    describe "#text" do
      let(:body) do
        slim """
          table
            thead
              tr
                th A
                th B
            tbody
              tr
                td 1
                td 2
              tr
                td 2
                td 3
        """
      end

      let(:table) do
        [
          ["A!","B!"],
          ["1!","2!"],
          ["2!","3!"],
        ]
      end

      it "overrides existing default text finder" do
        described_class.diff! "table", table_from(table) do
          text do |cell|
            cell.text + "!"
          end
        end
      end
    end

    describe "#allow_not_found" do
      it "permits the table to be missing" do
        described_class.diff! "table#missing", table_from([[]]) do
          allow_not_found
        end
      end

      it "throws an error otherwise" do
        expect {
          described_class.diff! "table#missing", double
        }.to raise_error(Capybara::ElementNotFound)
      end
    end

    describe "#header" do
      context "with arity of 0" do
        context "with block arity of 1" do
          let(:body) do
            slim """
              table
                thead
                  tr
                    th A
                    th B
                tbody
                  tr
                    td 1
                    td 2
                  tr
                    td 2
                    td 3
            """
          end

          let(:table) do
            [
              ["a","b"],
              ["1","2"],
              ["2","3"],
            ]
          end

          it "replaces the first row" do
            described_class.diff! "table", table_from(table) do
              header { |row| row.map(&:text).map(&:downcase) }
            end
          end
        end

        context "with block arity of 0" do
          let(:body) do
            slim """
              table
                tr
                  td 1
                  td 2
                tr
                  td 2
                  td 3
            """
          end

          let(:table) do
            [
              ["C","D"],
              ["1","2"],
              ["2","3"],
            ]
          end

          it "adds a first row" do
            described_class.diff! "table", table_from(table) do
              header { ["C","D"] }
            end
          end
        end
      end

      context "with arity of 1" do
        let(:body) do
          slim """
            table
              thead
                tr
                  th A
                  th B
              tbody
                tr
                  td 1
                  td 2
                tr
                  td 2
                  td 3
          """
        end

        let(:table) do
          [
            ["A","b"],
            ["1","2"],
            ["2","3"],
          ]
        end

        context "with an integer" do
          it "replaces the specified column in the header" do
            described_class.diff! "table", table_from(table) do
              header(1) { |cell| cell.text.downcase }
            end
          end
        end

        context "with a symbol" do
          it "replaces the specified column in the header" do
            described_class.diff! "table", table_from(table) do
              header(:b) { |cell| cell.text.downcase }
            end
          end
        end
      end
    end

    describe "#transformation" do
      let(:body) do
        slim """
          table
            thead
              tr
                th A
                th B
            tbody
              tr
                td 1
                td 2
              tr
                td 2
                td 3
        """
      end

      let(:table) do
        [
          ["B","C"],
          ["2","3"],
          ["3","4"],
        ]
      end

      it "allows arbitrary transformations on the intermediate data structure" do
        described_class.diff! "table", table_from(table) do
          transformation do |rows|
            rows.map! do |row|
              row.map(&:text).map(&:succ).map { |value| Capybara::Node::Simple.new(value) }
            end
          end
        end
      end
    end

    describe "#hash_transformation" do
      context "with normal header keys" do
        let(:body) do
          slim """
            table
              thead
                tr
                  th A
                  th B
              tbody
                tr
                  td 1
                  td 2
                tr
                  td 2
                  td 3
          """
        end

        let(:table) do
          [
            ["A","B"],
            ["2","4"],
            ["3","6"],
          ]
        end

        it "allows arbitrary transformations on a data structure of row hashes" do
          described_class.diff! "table", table_from(table) do
            hash_transformation do |hashes|
              hashes.map! do |hash|
                hash[:a] = hash[:a].text.to_i + 1
                hash[:b] = hash[:b].text.to_i * 2
                hash
              end
            end
          end
        end
      end

      context "with unicode keys" do
        let(:body) do
          slim """
            meta charset='utf-8'
            table
              thead
                tr
                  th ☆
                  th 🔒
              tbody
                tr
                  td 1
                  td 2
                tr
                  td 2
                  td 3
          """
        end

        let(:table) do
          [
            ["☆","🔒"],
            ["2","4"],
            ["3","6"],
          ]
        end

        it "allows arbitrary transformations on a data structure of row hashes" do
          described_class.diff! "table", table_from(table) do
            hash_transformation do |hashes|
              hashes.map! do |hash|
                hash[:☆] = hash[:☆].text.to_i + 1
                hash[:🔒] = hash[:🔒].text.to_i * 2
                hash
              end
            end
          end
        end
      end

      context "with blank keys" do
        let(:body) do
          slim """
            table
              thead
                tr
                  th &nbsp;
                  th &nbsp;
              tbody
                tr
                  td 1
                  td 2
                tr
                  td 2
                  td 3
          """
        end

        let(:table) do
          [
            [" "," "],
            ["2","4"],
            ["3","6"],
          ]
        end

        it "allows arbitrary transformations on a data structure of row hashes" do
          described_class.diff! "table", table_from(table) do
            hash_transformation do |hashes|
              hashes.map! do |hash|
                hash[1] = hash[1].text.to_i + 1
                hash[2] = hash[2].text.to_i * 2
                hash
              end
            end
          end
        end
      end
    end

    describe "#field" do
      let(:body) do
        slim """
          table
            thead
              tr
                th A
                th B
            tbody
              tr
                td 1
                td 2
              tr
                td 2
                td 3
        """
      end

      let(:table) do
        [
          ["A","B"],
          ["2","4"],
          ["3","6"],
        ]
      end

      it "replaces a field with a new value" do
        described_class.diff! "table", table_from(table) do
          field(:a) { |cell| cell.text.to_i + 1 }
          field(:b) { |cell| cell.text.to_i * 2 }
        end
      end
    end

    describe "#image" do
      let(:body) do
        slim """
          table
            thead
              tr
                th A
                th B
            tbody
              tr
                td: img src='/path/to/1.jpg?123456'
                td 1
              tr
                td: img src='/path/to/2-3a679bd0da8d45d2bf257420f948e1fe1b981b0d8cbac67d9992f22d61d5767e.jpg'
                td 2
        """
      end

      let(:table) do
        [
          ["A",    "B"],
          ["1.jpg","1"],
          ["2.jpg","2"],
        ]
      end

      it "replaces the cell with the image's filename, normalized" do
        described_class.diff! "table", table_from(table) do
          image :a
        end
      end
    end
  end

  def table_from table
    Cucumber::MultilineArgument::DataTable.from table
  end

  def slim template
    Slim::Template.new { template }.render
  end
end
