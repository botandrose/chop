require "spec_helper"
require "chop/table"
require "cucumber"
require "slim"

describe "Chop regex templates" do
  let(:app) do
    Proc.new { [200, {"Content-Type" => "text/html"}, [body]] }
  end

  before do
    Capybara.app = app
    Capybara.current_session.visit("/")
  end

  def table_from(table)
    Cucumber::MultilineArgument::DataTable.from(table)
  end

  def slim(template)
    Slim::Template.new { template }.render
  end

  context "Table .diff! with regex templates" do
    context "applies to all fields when enabled without args" do
      let(:body) do
        slim """
          table
            thead
              tr
                th Attachments
            tbody
              tr
                td attachment.jpg 23.4 KB browser-report.txt 1.26 KB
        """
      end

      it "matches embedded regex inside a literal cell" do
        expected = [
          ["Attachments"],
          ['attachment.jpg 23.4 KB browser-report.txt #{/1\.\d{2} KB/}']
        ]

        expect {
          Chop::Table.diff!("table", table_from(expected)) do
            regex
          end
        }.not_to raise_error
      end
    end

    context "whitelist by header names" do
      let(:body) do
        slim """
          table
            thead
              tr
                th A
                th B
            tbody
              tr
                td foo 123
                td bar 456
        """
      end

      it "matches only in whitelisted header columns" do
        expected = [
          ["A", "B"],
          ["foo 123", 'bar #{/\d{3}/}']
        ]

        expect {
          Chop::Table.diff!("table", table_from(expected)) do
            regex :b
          end
        }.not_to raise_error
      end

      it "treats tokens as literal in non-whitelisted columns" do
        expected = [
          ["A", "B"],
          ['#{/\w+ \d{3}/}', "bar 456"]
        ]

        expect {
          Chop::Table.diff!("table", table_from(expected)) do
            regex :b
          end
        }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
      end
    end

    context "whitelist by 1-based column index" do
      let(:body) do
        slim """
          table
            tr
              th A
              th B
            tr
              td foo 123
              td bar 456
        """
      end

      it "applies to the specified index only" do
        expected = [
          ["A", "B"],
          ["foo 123", 'bar #{/\d{3}/}']
        ]

        expect {
          Chop::Table.diff!("table", table_from(expected)) do
            regex 2
          end
        }.not_to raise_error
      end

      it "does not apply to other indexes" do
        expected = [
          ["A", "B"],
          ['#{/\w+ \d{3}/}', "bar 456"]
        ]

        expect {
          Chop::Table.diff!("table", table_from(expected)) do
            regex 2
          end
        }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
      end
    end
  end
end
