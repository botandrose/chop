require "spec_helper"
require "chop/unordered_list"
require "cucumber"
require "capybara"
require "puma"
require "slim"

describe Chop::UnorderedList do
  let(:app) do
    Proc.new { [200, {"Content-Type" => "text/html"}, [body]] }
  end

  before do
    Capybara.app = app
    Capybara.server = :puma, { Silent: true }
    Capybara.current_session.visit("/")
  end

  describe ".diff!" do
    let(:body) do
      slim """
        ul
          li 1
          li 2
      """
    end

    let(:ul) do
      [
        ["1"],
        ["2"],
      ]
    end

    it "converts the selector to a table and diffs it with the supplied table" do
      described_class.diff! "ul", table_from(ul)
    end

    it "fails the diff when the tables are different" do
      expect {
        described_class.diff! "ul", table_from([[]])
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
