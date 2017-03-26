require "spec_helper"
require "chop/definition_list"
require "cucumber"
require "capybara"
require "slim"

describe Chop::DefinitionList do
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
        dl
          dt A
          dd 1
          dt B
          dd 2
      """
    end

    let(:dl) do
      [
        ["A", "1"],
        ["B", "2"],
      ]
    end

    it "converts the selector to a table and diffs it with the supplied table" do
      described_class.diff! "dl", table_from(dl)
    end

    it "fails the diff when the tables are different" do
      expect {
        described_class.diff! "dl", table_from([[]])
      }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
    end

    describe "block methods" do
      describe "#column" do
        it "transforms a column by index" do
          dl = [
            ["A", "2"],
            ["B", "4"],
          ]
          described_class.diff! "dl", table_from(dl) do
            column 1 do |cell|
              cell.text.to_i * 2
            end
          end
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
