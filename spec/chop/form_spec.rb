require "spec_helper"
require "chop/form"
require "cucumber"
require "capybara"
require "capybara/poltergeist"
require "slim"

describe Chop::Form do
  describe ".fill_in!" do
    describe "texty fields" do
      %w(text email search tel url password month week date datetime time).each do |type|
        it "fills in #{type} fields" do
          session = test_app <<-SLIM
            label for="f" F
            input id="f" type="#{type}"
          SLIM
          described_class.fill_in! table_from([["F", "V"]])
          expect(session.find_field("F").value).to eq "V"
        end
      end
    end

    it "fills in range fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="range" min="0" max="100"
      SLIM
      described_class.fill_in! table_from([["F", "100"]])
      expect(session.find_field("F").value).to eq "100"
    end

    it "fills in number fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="number"
      SLIM
      described_class.fill_in! table_from([["F", "50"]])
      expect(session.find_field("F").value).to eq "50"
    end

    it "fills in color fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="color"
      SLIM
      described_class.fill_in! table_from([["F", "#000000"]])
      expect(session.find_field("F").value).to eq "#000000"
    end

    it "fills in textareas" do
      session = test_app <<-SLIM
        label for="f" F
        textarea id="f"
      SLIM
      described_class.fill_in! table_from([["F", "V"]])
      expect(session.find_field("F").value).to eq "V"
    end

    it "selects select boxes" do
      session = test_app <<-SLIM
        label for="f" F
        select id="f"
          option
          option T
          option V
      SLIM
      described_class.fill_in! table_from([["F", "V"]])
      expect(session.find_field("F").value).to eq "V"
    end

    it "selects multiple select boxes delimited by comma-space" do
      session = test_app <<-SLIM
        label for="f" F
        select id="f" multiple="multiple"
          option
          option T
          option U
          option V
      SLIM
      described_class.fill_in! table_from([["F", "T, V"]])
      expect(session.find_field("F").value).to eq ["T","V"]
    end

    describe "radio buttons" do
      it "chooses a radio button" do
        session = test_app <<-SLIM
          label for="f" F
          input id="f" type="radio" name="f"
        SLIM
        described_class.fill_in! table_from([["F", "V"]])
        expect(session.find_field("F")).to be_checked
      end

      context "with non-standard labelling for groups" do
        it "chooses a radio button" do
          session = test_app <<-SLIM
            label for="f_p" F
            input type="radio" value="P" name="f" id="f_p"
            label for="f_p" P
            input type="radio" value="V" name="f" id="f_v"
            label for="f_v" V
          SLIM
          described_class.fill_in! table_from([["F", "V"]])
          expect(session.find_field("f_v")).to be_checked
        end
      end
    end

    describe "checkboxes" do
      it "checks a checkbox" do
        session = test_app <<-SLIM
          label for="f" F
          input id="f" type="checkbox"
        SLIM
        described_class.fill_in! table_from([["F", "V"]])
        expect(session.find_field("F")).to be_checked
      end

      it "unchecks a checkbox" do
        session = test_app <<-SLIM
          label for="f" F
          input id="f" type="checkbox"
        SLIM
        described_class.fill_in! table_from([["F", ""]])
        expect(session.find_field("F")).to_not be_checked
      end

      context "with non-standard labelling for groups" do
        it "checks a checkbox" do
          session = test_app <<-SLIM
            label for="f_p" F
            input type="checkbox" value="P" name="f[]" id="f_p"
            label for="f_p" P
            input type="checkbox" value="V" name="f[]" id="f_v"
            label for="f_v" V
          SLIM
          described_class.fill_in! table_from([["F", "V"]])
          expect(session.find_field("f_p")).to_not be_checked
          expect(session.find_field("f_v")).to be_checked
        end

        it "checks multiple checkboxes" do
          session = test_app <<-SLIM
            label for="f_p" F
            input type="checkbox" value="P" name="f[]" id="f_p"
            label for="f_p" P
            input type="checkbox" value="V" name="f[]" id="f_v"
            label for="f_v" V
            input type="checkbox" value="W" name="f[]" id="f_w"
            label for="f_w" W
          SLIM
          described_class.fill_in! table_from([["F", "V, W"]])
          expect(session.find_field("f_p")).to_not be_checked
          expect(session.find_field("f_v")).to be_checked
          expect(session.find_field("f_w")).to be_checked
        end
      end
    end

    it "attaches files to file fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="file"
      SLIM
      described_class.fill_in! table_from([["F", "README.md"]]), path: "./"
      expect(session.find_field("F").value).to eq "C:\\fakepath\\README.md"
    end
  end 

  def table_from table
    Cucumber::MultilineArgument::DataTable.from table
  end

  def test_app template
    Capybara.app = slim_app(template)
    Capybara.default_driver = :poltergeist
    session = Capybara.current_session
    session.visit("/")
    session
  end

  def slim_app template
    Proc.new { [200, {"Content-Type" => "text/html"}, [slim(template)]] }
  end

  def slim template
    Slim::Template.new { template }.render
  end
end
