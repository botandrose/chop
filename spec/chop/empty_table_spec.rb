require "spec_helper"
require "chop"
require "cucumber"
require "capybara"
require "puma"
require "slim"

describe "Chop.empty_table" do
  it "is an empty Cucumber table" do
    expect(Chop.empty_table.raw).to eq([[]])
  end


  describe "#diff!" do
    let(:app) do
      Proc.new { [200, {"Content-Type" => "text/html"}, [body]] }
    end

    before do
      Capybara.app = app
      Capybara.server = :puma, { Silent: true }
      Capybara.current_session.visit("/")
    end

    let(:body) do
      slim """
        dl.present
          dt A
          dd 1
          dt B
          dd 2

        dl.empty
      """
    end

    it "passes against a non-existant element" do
      Chop.empty_table.diff!("table")
    end

    it "passes against an empty element" do
      Chop.empty_table.diff!(".empty")
    end

    it "fails against an non-empty element" do
      expect { Chop.empty_table.diff!(".present") }.to \
        raise_exception(Cucumber::MultilineArgument::DataTable::Different)
    end
  end

  def slim template
    Slim::Template.new { template }.render
  end
end
