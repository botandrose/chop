require "spec_helper"
require "chop/table"
require "cucumber"
require "capybara"
require "slim"

describe Chop::Table do
  let(:app) do
    Proc.new { [200, {"Content-Type" => "text/html"}, [body]] }
  end

  before do
    Capybara.app = app
    Capybara.current_session.visit("/")
  end

  describe ".diff!" do
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
      described_class.diff! table_from(table)
    end

    it "fails the diff when the tables are different" do
      expect {
        described_class.diff! table_from([[]])
      }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
    end
  end 

  def table_from table
    Cucumber::MultilineArgument::DataTable.from table
  end

  def slim template
    Slim::Template.new { template }.render
  end
end
