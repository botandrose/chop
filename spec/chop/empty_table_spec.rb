require "spec_helper"
require "chop"
require "cucumber"
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

    context "when the element is removed after the diff begins" do
      let(:body) do
        slim """
          dl.doomed
            dt A
            dd 1
          javascript:
            setTimeout(() => document.querySelector('.doomed').remove(), 500)
        """
      end

      it "passes" do
        Chop.empty_table.diff!(".doomed")
      end
    end
  end

  def slim template
    Slim::Template.new { template }.render
  end
end
