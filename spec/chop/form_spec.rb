require "spec_helper"
require "chop/form"
require "cucumber"
require "capybara"
require "capybara/cuprite"
require "slim"

module FileFieldFiles
  refine Capybara::Node::Element do
    def files
      session.evaluate_script("Array.prototype.map.call(document.getElementById('#{self["id"]}').files, function(file) { return file.name })")
    end
  end
end
using FileFieldFiles

describe Chop::Form do
  describe ".diff!" do
    let(:app) do
      Proc.new { [200, {"Content-Type" => "text/html"}, [body]] }
    end

    before do
      Capybara.app = app
      Capybara.server = :webrick
      Capybara.current_session.visit("/")
    end

    describe ".diff!" do
      context "text boxes" do
        let(:body) do
          slim """
            form
              label for='a' A
              input id='a' name='a' value='1'
              label for='b' B
              input id='b' name='b' value='2'
          """
        end

        let(:form) do
          [
            ["A", "1"],
            ["B", "2"],
          ]
        end

        it "converts the selector to a table and diffs it with the supplied table" do
          described_class.diff! "form", table_from(form)
        end

        it "fails the diff when the tables are different" do
          expect {
            described_class.diff! "form", table_from([["A","2"]])
          }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
        end

        it "doesn't fail the diff when the rows are missing from assertion" do
          expect {
            described_class.diff! "form", table_from([[]])
          }.to_not raise_exception
        end

        it "accepts a capybara element as a diff target" do
          form_element = Capybara.current_session.find("form")
          described_class.diff! form_element, table_from(form)
        end
      end

      context "multiple checkboxes" do
        let(:body) do
          slim <<~SLIM
            form
              label for="f_p" F
              input type="checkbox" value="P" name="f[]" id="f_p"
              label for="f_p" P
              input type="checkbox" value="V" name="f[]" id="f_v" checked=true
              label for="f_v" V
              input type="checkbox" value="W" name="f[]" id="f_w" checked=true
              label for="f_w" W
          SLIM
        end

        it "joins the values with a comma" do
          described_class.diff! "form", table_from([["F", "V, W"]])
        end
      end
    end
  end

  describe ".fill_in!" do
    describe "texty fields" do
      %w(text email search tel url password datetime).each do |type|
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

    it "fills in time fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="time"
      SLIM
      described_class.fill_in! table_from([["F", "12:33:45"]])
      expect(session.find_field("F").value).to eq "12:33:45"
    end

    it "fills in date fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="date"
      SLIM
      described_class.fill_in! table_from([["F", "2020-06-19"]])
      expect(session.find_field("F").value).to eq "2020-06-19"
    end

    it "fills in week fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="week"
      SLIM
      described_class.fill_in! table_from([["F", "2020-W06"]])
      expect(session.find_field("F").value).to eq "2020-W06"
    end

    it "fills in month fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="month"
      SLIM
      described_class.fill_in! table_from([["F", "2020-06"]])
      expect(session.find_field("F").value).to eq "2020-06"
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
        it "chooses a radio button by value" do
          session = test_app <<-SLIM
            label for="f_p" F
            input type="radio" value="P" name="f" id="f_p"
            label for="f_p" Power
            input type="radio" value="V" name="f" id="f_v"
            label for="f_v" Value
          SLIM
          described_class.fill_in! table_from([["F", "V"]])
          expect(session.find_field("f_v")).to be_checked
        end

        it "chooses a radio button by label" do
          session = test_app <<-SLIM
            label for="f_p" F
            input type="radio" value="Power" name="f" id="f_p"
            label for="f_p" P
            input type="radio" value="Value" name="f" id="f_v"
            label for="f_v" V
          SLIM
          described_class.fill_in! table_from([["F", "V"]])
          expect(session.find_field("f_v")).to be_checked
        end

        it "favors later radio buttons if multiple match (to avoid initial label if group label matches selection label)" do
          session = test_app <<-SLIM
            label for="f_p" F?
            input type="radio" value="Power" name="f" id="f_p"
            label for="f_p" P
            input type="radio" value="Value" name="f" id="f_v"
            label for="f_v" F
          SLIM
          described_class.fill_in! table_from([["F", "F"]])
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

    describe "file fields" do
      context "single file field" do
        let!(:session) { test_app <<-SLIM }
          label for="f" F
          input id="f" type="file"
        SLIM

        it "attaches a file to a file field" do
          described_class.fill_in! table_from([["F", "README.md"]]), path: "./"
          expect(session.find_field("F").files).to eq ["README.md"]
        end

        it "complains when file does not exist" do
          expect {
            described_class.fill_in! table_from([["F", "DOES-NOT-EXIST"]]), path: "./"
          }.to raise_error(Errno::ENOENT)
        end

        it "complains when trying to attach multiple files" do
          expect {
            described_class.fill_in! table_from([["F", "README.md chop.gemspec"]]), path: "./"
          }.to raise_error(TypeError)
        end
      end

      context "multiple file field" do
        let!(:session) { test_app <<-SLIM }
          label for="f" F
          input id="f" type="file" multiple="multiple"
        SLIM

        it "attaches multiple files to a file field" do
          described_class.fill_in! table_from([["F", "README.md chop.gemspec"]]), path: "./"
          expect(session.find_field("F").files).to eq ["README.md", "chop.gemspec"]
        end

        it "attaches a single file to a file field" do
          described_class.fill_in! table_from([["F", "README.md"]]), path: "./"
          expect(session.find_field("F").files).to eq ["README.md"]
        end

        it "complains when a file does not exist" do
          expect {
            described_class.fill_in! table_from([["F", "README.md DOES-NOT-EXIST"]]), path: "./"
          }.to raise_error(Errno::ENOENT)
        end
      end
    end
  end 

  def table_from table
    Cucumber::MultilineArgument::DataTable.from table
  end

  def test_app template
    Capybara.app = slim_app(template)
    Capybara.server = :webrick
    Capybara.default_driver = :cuprite
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

